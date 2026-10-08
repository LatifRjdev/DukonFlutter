import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/subscription/subscription_bloc.dart';
import '../../blocs/subscription/subscription_event.dart';
import '../../blocs/subscription/subscription_state.dart';

/// Which flag a gated entry point needs.
typedef PlanFeatureSelector = bool Function(SubscriptionFeatures features);

/// The cheapest plan whose config carries [needs], or null if no plan does.
///
/// The dialog used to say "Доступно на тарифе PREMIUM" for everything. Zakat,
/// loyalty and batch profitability are on BUSINESS, so a START merchant was
/// told to buy PREMIUM for something the next tier up already includes. The app
/// can tell the truth now only because availablePlans carries each plan's
/// flags.
///
/// Ordered by price rather than by list order: the server sorts, but a caller
/// that filters or reverses the list must not change the answer.
String? cheapestPlanWith(
  List<SubscriptionPlanOption> plans,
  PlanFeatureSelector needs,
) {
  final eligible = plans.where((p) => needs(p.features)).toList()
    ..sort((a, b) => a.listPrice.compareTo(b.listPrice));
  return eligible.isEmpty ? null : eligible.first.plan;
}

/// What a gated tile should do right now.
enum PlanGateVerdict {
  /// Subscription state has not arrived. Do NOT render a lock yet — the tile
  /// would flash one on every cold start. Disable the tap instead.
  undetermined,

  /// The plan includes it: behave normally.
  allowed,

  /// Confirmed excluded: badge it and open the dialog on tap.
  blocked,
}

class PlanGate {
  final PlanGateVerdict verdict;

  /// The plan to name in the badge and the dialog. Null when [verdict] is not
  /// [PlanGateVerdict.blocked], or when no plan offers the feature at all —
  /// in which case there is nothing honest to upsell and the caller should
  /// hide the entry point rather than promise a tier that does not exist.
  final String? requiredPlan;

  const PlanGate._(this.verdict, this.requiredPlan);

  /// Mirrors the branch already used for the e-commerce tile, which correctly
  /// separates "still loading" from "confirmed ineligible".
  factory PlanGate.of(SubscriptionState state, PlanFeatureSelector needs) {
    if (state is! SubscriptionLoaded) {
      return const PlanGate._(PlanGateVerdict.undetermined, null);
    }
    if (needs(state.features)) {
      return const PlanGate._(PlanGateVerdict.allowed, null);
    }
    return PlanGate._(
      PlanGateVerdict.blocked,
      cheapestPlanWith(state.availablePlans, needs),
    );
  }

  bool get isAllowed => verdict == PlanGateVerdict.allowed;
  bool get isUndetermined => verdict == PlanGateVerdict.undetermined;

  /// Blocked AND there is a real plan to point at. A blocked gate with no
  /// nameable plan must not render "Доступно на тарифе null".
  bool get isUpsellable =>
      verdict == PlanGateVerdict.blocked && requiredPlan != null;
}

/// Resolves a [PlanGate] for [needs], loading the subscription first if nothing
/// has yet.
///
/// Gating a screen on a flag only works if the flag has arrived. Until 2026-10
/// `SubscriptionLoadRequested` was dispatched from exactly two places —
/// settings_page's initState and the subscription page — which was fine while
/// the only gated tile lived on the settings page itself. The moment gates
/// appeared on the "Ещё" menu and the product detail page, a merchant who
/// opened neither of those screens left the bloc in [SubscriptionInitial]
/// forever, so the gate read `undetermined` and the tile stayed disabled — for
/// entitled merchants too. That turns "the server refuses it" into "the app
/// refuses it", which is worse than the 403 the gating was meant to replace.
///
/// So the load is requested here rather than at each call site: a gate that can
/// be added to a screen without remembering to also wire its data is the only
/// kind that stays correct.
class PlanGateBuilder extends StatefulWidget {
  final PlanFeatureSelector needs;
  final String storeId;
  final Widget Function(BuildContext context, PlanGate gate) builder;

  const PlanGateBuilder({
    super.key,
    required this.needs,
    required this.storeId,
    required this.builder,
  });

  @override
  State<PlanGateBuilder> createState() => _PlanGateBuilderState();
}

class _PlanGateBuilderState extends State<PlanGateBuilder> {
  /// The store we have already asked about. Non-null means a request went out.
  String? _requestedFor;

  /// Requested from `build`, not `initState`, because the store arrives late.
  ///
  /// HomePage builds all five tabs eagerly, so this widget's initState can run
  /// before StoreBloc has a selected store — `storeId` is then empty, there is
  /// nothing to ask about, and initState never runs again. The tile stayed
  /// disabled forever for entitled merchants, which is exactly what this
  /// builder exists to prevent. Found on the emulator: a BUSINESS merchant,
  /// whose plan includes zakat, saw the Закят tile greyed out.
  ///
  /// Guarded by [_requestedFor] and by the state still being
  /// [SubscriptionInitial], so a rebuild cannot re-ask — the throttle is 100
  /// requests a minute and this widget rebuilds on every bloc emission.
  void _ensureRequested(SubscriptionState state) {
    if (widget.storeId.isEmpty) return;
    if (_requestedFor == widget.storeId) return;
    if (state is! SubscriptionInitial) return;
    _requestedFor = widget.storeId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SubscriptionBloc>().add(
        SubscriptionLoadRequested(storeId: widget.storeId),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, state) {
        _ensureRequested(state);
        return widget.builder(context, PlanGate.of(state, widget.needs));
      },
    );
  }
}
