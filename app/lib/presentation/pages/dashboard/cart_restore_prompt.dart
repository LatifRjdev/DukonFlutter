import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Восстановить корзину?'),
        content: Text(
          'Найдена сохранённая корзина '
          '(${_relativeTime(saved.savedAt)}, '
          '${saved.state.itemCount} товаров).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Очистить'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Восстановить'),
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

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    return '${diff.inDays} дн назад';
  }
}
