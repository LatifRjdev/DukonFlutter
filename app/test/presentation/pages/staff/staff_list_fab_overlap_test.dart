// Regression test for post-plan SPEC.md audit finding #7: the staff list's
// ListView had no bottom padding reserved for the FAB, so when the list
// exactly fills the viewport, the last card's tappable area could sit under
// the floating "add staff" button.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/staff_member.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_bloc.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_event.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_state.dart';
import 'package:dukonpro/presentation/pages/staff/staff_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockStaffBloc extends MockBloc<StaffEvent, StaffState>
    implements StaffBloc {}

void main() {
  late _MockStaffBloc staffBloc;

  // Enough staff to fill a 412x900 viewport and then some, so the last
  // card's position is determined by the ListView's bottom padding rather
  // than by there simply being empty space below a short list.
  final staff = List.generate(
    10,
    (i) => StaffMember(
      id: 'staff-$i',
      storeId: 'store-1',
      name: 'Сотрудник $i',
      phone: '+99290000000$i',
      role: 'CASHIER',
      createdAt: DateTime(2024, 1, 1),
    ),
  );

  setUp(() {
    staffBloc = _MockStaffBloc();
    when(() => staffBloc.state).thenReturn(
      StaffLoaded(staff: staff, total: staff.length, totalPages: 1),
    );
  });

  tearDown(() {
    staffBloc.close();
  });

  Widget page() => const StaffListPage(storeId: 'test-store-id');

  Widget wrapWithBlocs(Widget child) => BlocProvider<StaffBloc>.value(
        value: staffBloc,
        child: child,
      );

  testWidgets(
      'the last staff card in a full-viewport list does not sit under the '
      'FAB (SPEC.md audit finding #7)', (tester) async {
    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      wrap: wrapWithBlocs,
      size: const Size(412, 900),
    );

    // Scroll all the way to the end — the overlap only manifests once the
    // user has scrolled the last card into its resting position at the
    // bottom of the scrollable content; bottom padding on the ListView
    // extends how far that scroll can go, not the last card's position
    // before scrolling.
    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
    await tester.pumpAndSettle();

    final fabRect = tester.getRect(find.byType(FloatingActionButton));
    final lastCard = find.ancestor(
      of: find.text('Сотрудник 9'),
      matching: find.byType(GestureDetector),
    );
    final lastCardRect = tester.getRect(lastCard);

    // The card's bottom edge must sit at or above the FAB's top edge — no
    // vertical overlap between the two.
    expect(
      lastCardRect.bottom,
      lessThanOrEqualTo(fabRect.top),
      reason:
          'Last staff card (bottom: ${lastCardRect.bottom}) overlaps the '
          'FAB (top: ${fabRect.top})',
    );
  });
}
