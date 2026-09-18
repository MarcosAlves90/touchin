import 'package:touchin_flutter/features/shared/presentation/widgets/pagination_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders pagination summary and triggers navigation',
      (tester) async {
    var previousCalls = 0;
    var nextCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: PaginationControls(
              page: 2,
              totalPages: 3,
              hasPrevious: true,
              hasNext: true,
              onPrevious: () => previousCalls += 1,
              onNext: () => nextCalls += 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Página 2 de 3'), findsOneWidget);

    await tester.tap(find.text('Anterior'));
    await tester.tap(find.text('Próxima'));
    await tester.pump();

    expect(previousCalls, 1);
    expect(nextCalls, 1);
  });
}
