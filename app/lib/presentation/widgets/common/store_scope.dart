import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

/// Supplies the identity of the selected store, held steady across the
/// transient states a store-list reload passes through.
///
/// The key built from this drives the store-scoped provider subtree, so every
/// change disposes ~23 blocs and makes every open screen refetch. `StoreBloc`
/// emits `StoreLoading` before each reload and `StoreError` on failure, and
/// `StoreLoadRequested` is dispatched on cold start, on pull to refresh and
/// after editing a store — so deriving the key from the current state alone
/// tore the subtree down several times per session, dropping an in-progress
/// POS cart, and on `StoreError` left every screen empty with nothing
/// scheduled to reload it.
///
/// Only `StoreLoaded` moves the key. It is the settled truth, including when
/// it carries no selection at all (the user deleted their last store); every
/// other state is a step on the way to one and is ignored.
///
/// This widget is built inside the session-keyed subtree, below the provider
/// that owns `StoreBloc`, so a new session constructs a new instance whose
/// retained id starts null. A store id therefore cannot outlive the account
/// that selected it — the regression fixed in 2082dc8.
class StoreScope extends StatefulWidget {
  const StoreScope({super.key, required this.builder});

  final Widget Function(BuildContext context, String storeKey) builder;

  @override
  State<StoreScope> createState() => _StoreScopeState();
}

class _StoreScopeState extends State<StoreScope> {
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _storeId = _selectedIdOf(context.read<StoreBloc>().state);
  }

  static String? _selectedIdOf(StoreState state) =>
      state is StoreLoaded ? state.selectedStore?.id : null;

  @override
  Widget build(BuildContext context) {
    return BlocListener<StoreBloc, StoreState>(
      listenWhen: (previous, current) =>
          current is StoreLoaded && _selectedIdOf(current) != _storeId,
      listener: (context, state) =>
          setState(() => _storeId = _selectedIdOf(state)),
      child: widget.builder(
        context,
        _storeId == null ? 'no-store' : 'store:$_storeId',
      ),
    );
  }
}
