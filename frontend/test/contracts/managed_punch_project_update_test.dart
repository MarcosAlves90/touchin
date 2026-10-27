import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';

void main() {
  final timestamp = DateTime.utc(2026, 10, 25, 12);

  test('editing a punch sends explicit null when its project was cleared', () {
    final draft = ManagedPunchDraft(
      type: PunchType.checkOut,
      timestamp: timestamp,
      detail: 'Ajuste',
    );

    expect(draft.toCreateApiJson().containsKey('projectId'), isFalse);
    expect(draft.toUpdateApiJson().containsKey('projectId'), isTrue);
    expect(draft.toUpdateApiJson()['projectId'], isNull);
  });

  test('copyWith distinguishes omitted project from explicit null', () {
    final original = ManagedPunchDraft(
      type: PunchType.checkIn,
      timestamp: timestamp,
      detail: 'Entrada',
      projectId: 'projeto-antigo',
    );

    expect(original.copyWith(detail: 'Corrigido').projectId, 'projeto-antigo');
    final cleared = original.copyWith(projectId: null);
    expect(cleared.projectId, isNull);
    expect(cleared.toUpdateApiJson()['projectId'], isNull);
  });

  test('editing preserves and trims a nonempty project', () {
    final draft = ManagedPunchDraft(
      type: PunchType.checkIn,
      timestamp: timestamp,
      detail: 'Entrada',
      projectId: '  projeto-valido  ',
    );
    expect(draft.toUpdateApiJson()['projectId'], 'projeto-valido');
  });
}
