class Validators {
  Validators._();

  static String? required(String? value, [String fieldName = 'Поле']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName обязательно для заполнения';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите номер телефона';
    }
    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 9) {
      return 'Номер телефона должен содержать 9 цифр';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < 6) {
      return 'Пароль должен содержать минимум 6 символов';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Неверный формат email';
    }
    return null;
  }

  static String? price(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите цену';
    }
    final number = double.tryParse(value);
    if (number == null || number < 0) {
      return 'Введите корректную цену';
    }
    return null;
  }

  static String? quantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите количество';
    }
    final number = double.tryParse(value);
    if (number == null || number < 0) {
      return 'Введите корректное количество';
    }
    return null;
  }
}
