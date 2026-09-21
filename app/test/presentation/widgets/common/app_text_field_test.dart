import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukonpro/presentation/widgets/common/app_text_field.dart';

Widget _host(GlobalKey<FormState> formKey, TextEditingController controller) {
  return MaterialApp(
    home: Scaffold(
      body: Form(
        key: formKey,
        child: AppTextField(
          controller: controller,
          label: 'Имя',
          validator: (v) => (v == null || v.isEmpty) ? 'Введите имя' : null,
        ),
      ),
    ),
  );
}

void main() {
  group('AppTextField validation', () {
    // Regression test: on several screens (e.g. "Добавить вложение",
    // "Принять оплату") a validation error shown after a failed submit
    // stayed on screen even after the user corrected the field, because
    // TextFormField's default autovalidateMode only re-validates on an
    // explicit Form.validate() call. Fixed by setting
    // autovalidateMode: AutovalidateMode.onUserInteraction in
    // app_text_field.dart, which re-validates as the user types once the
    // field has been through at least one validation pass.
    testWidgets(
        'clears its error automatically once the user fixes the value, '
        'without a second explicit Form.validate() call', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();
      await tester.pumpWidget(_host(formKey, controller));

      // Trigger the initial validation failure, as a submit button would.
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Введите имя'), findsOneWidget);

      // Fix the field directly, without calling validate() again.
      await tester.enterText(find.byType(AppTextField), 'Test');
      await tester.pump();

      expect(find.text('Введите имя'), findsNothing);
    });

    testWidgets('does not show an error before any validation attempt',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();
      await tester.pumpWidget(_host(formKey, controller));

      expect(find.text('Введите имя'), findsNothing);
    });
  });
}
