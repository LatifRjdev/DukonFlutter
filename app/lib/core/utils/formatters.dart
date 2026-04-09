import 'package:intl/intl.dart';
import '../constants/enums.dart';

class Formatters {
  Formatters._();

  static String price(double amount, {Currency currency = Currency.tjs}) {
    final formatter = NumberFormat('#,##0.00', 'ru_RU');
    return '${formatter.format(amount)} ${currency.symbol}';
  }

  static String number(int value) {
    final formatter = NumberFormat('#,###', 'ru_RU');
    return formatter.format(value);
  }

  static String date(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  static String time(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static String phone(String phone) {
    if (phone.length == 12 && phone.startsWith('+992')) {
      return '+992 ${phone.substring(4, 6)} ${phone.substring(6, 9)} ${phone.substring(9)}';
    }
    return phone;
  }

  static String quantity(double qty, ProductUnit unit) {
    if (unit == ProductUnit.pcs) {
      return '${qty.toInt()} ${unit.displayName}';
    }
    return '${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} ${unit.displayName}';
  }
}
