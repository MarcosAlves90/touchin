import 'package:touchin_flutter/core/forms/br_input_masks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats CNPJ and enforces 14 digits', () {
    final result = BrInputMasks.cnpjFormatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '1234567890123456',
        selection: TextSelection.collapsed(offset: 16),
      ),
    );

    expect(result.text, '12.345.678/9012-34');
    expect(BrInputMasks.hasValidCnpjDigits(result.text), isTrue);
  });

  test('formats 11-digit phone and ignores extra digits', () {
    final result = BrInputMasks.phoneFormatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '119876543210',
        selection: TextSelection.collapsed(offset: 12),
      ),
    );

    expect(result.text, '(11) 98765-4321');
    expect(BrInputMasks.hasValidPhoneDigits(result.text), isTrue);
  });

  test('formats 10-digit phone with landline mask', () {
    final result = BrInputMasks.formatPhone('1133334444');

    expect(result, '(11) 3333-4444');
    expect(BrInputMasks.hasValidPhoneDigits(result), isTrue);
  });

  test('rejects inserting into a full CNPJ without losing trailing digits', () {
    const old = TextEditingValue(
      text: '12.345.678/9012-34',
      selection: TextSelection.collapsed(offset: 3),
    );
    final result = BrInputMasks.cnpjFormatter.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '12.9345.678/9012-34',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    expect(result.text, old.text);
    expect(result.selection, old.selection);
  });

  test('rejects paste overflow for near-full CNPJ without losing digits', () {
    const old = TextEditingValue(
      text: '12.345.678/9012-3',
      selection: TextSelection.collapsed(offset: 3),
    );
    final result = BrInputMasks.cnpjFormatter.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '12.99345.678/9012-3',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );

    expect(result.text, old.text);
    expect(result.selection, old.selection);
  });

  test('rejects paste overflow for near-full phone without losing digits', () {
    const old = TextEditingValue(
      text: '(11) 9876-5432',
      selection: TextSelection.collapsed(offset: 5),
    );
    final result = BrInputMasks.phoneFormatter.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '(11) 889876-5432',
        selection: TextSelection.collapsed(offset: 7),
      ),
    );

    expect(result.text, old.text);
    expect(result.selection, old.selection);
  });

  test('allows replacing selected digits in a full phone', () {
    final old = const TextEditingValue(
      text: '(11) 98765-4321',
      selection: TextSelection(baseOffset: 5, extentOffset: 10),
    );
    final result = BrInputMasks.phoneFormatter.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '(11) 12345-4321',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );
    expect(result.text, '(11) 12345-4321');
  });

  test('Delete on a CNPJ separator removes the following digit', () {
    const old = TextEditingValue(
      text: '12.345.678/9012-34',
      selection: TextSelection.collapsed(offset: 2),
    );
    final result = BrInputMasks.cnpjFormatter.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '12345.678/9012-34',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    expect(result.text, '12.456.789/0123-4');
  });

  test('Backspace on a CNPJ separator removes preceding digit', () {
    const old = TextEditingValue(
      text: '12.345.678/9012-34',
      selection: TextSelection.collapsed(offset: 3),
    );
    final result = BrInputMasks.cnpjFormatter.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '12345.678/9012-34',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    expect(result.text, '13.456.789/0123-4');
  });
}
