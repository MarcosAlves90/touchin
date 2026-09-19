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
}
