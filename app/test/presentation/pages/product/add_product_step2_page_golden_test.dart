import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_bloc.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_event.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_state.dart';
import 'package:dukonpro/presentation/pages/product/add_product_step2_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class MockProductFormBloc extends MockBloc<ProductFormEvent, ProductFormState>
    implements ProductFormBloc {}

void main() {
  late MockProductFormBloc productFormBloc;

  setUp(() {
    productFormBloc = MockProductFormBloc();
    when(() => productFormBloc.state).thenReturn(const ProductFormState());
  });

  Widget page() => const AddProductStep2Page();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<ProductFormBloc>.value(value: productFormBloc),
        ],
        child: child,
      );

  group('AddProductStep2Page goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'add_product_step2_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'add_product_step2_dark');
    });
  });
}
