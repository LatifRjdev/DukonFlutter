import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../data/datasources/local/cart_local_datasource.dart';
import '../../../injection.dart';
import '../../blocs/pos/cart_bloc.dart';
import '../../blocs/pos/cart_event.dart';

/// E.4 follow-up: prompts the user to restore a previously persisted
/// cart on app cold start. Never auto-restores — the restore is
/// always opt-in to avoid surprising the cashier with yesterday's
/// cart on the first sale of the day.
class CartRestorePrompt {
  static bool _shown = false;

  /// Resets the "already shown this session" guard. Used by
  /// `app/integration_test/lifecycle_test.dart` so each test case
  /// starts from a clean cold-start.
  @visibleForTesting
  static void resetForTest() {
    _shown = false;
  }

  static Future<void> showIfNeeded(BuildContext context) async {
    if (_shown) return;
    _shown = true;

    final ds = sl<CartLocalDatasource>();
    final saved = ds.load();
    if (saved == null) return;

    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cartRestoreDialogTitle),
        content: Text(
          l10n.cartRestoreDialogMessage(
            _relativeTime(saved.savedAt, l10n),
            '${saved.state.itemCount}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.clear),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.restore),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (result == true) {
      context.read<CartBloc>().add(CartRestored(saved.state));
    } else {
      await ds.clear();
    }
  }

  static String _relativeTime(DateTime t, AppLocalizations l10n) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo('${diff.inMinutes}');
    if (diff.inHours < 24) return l10n.hoursAgo('${diff.inHours}');
    return l10n.daysAgo('${diff.inDays}');
  }
}
