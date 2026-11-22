import 'package:app/util/formatos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CPF', () {
    expect(cpfValido('529.982.247-25'), isTrue);
    expect(cpfValido('529.982.247-24'), isFalse);
    expect(cpfValido('111.111.111-11'), isFalse);
    expect(cpfValido('123'), isFalse);
  });

  test('placa antiga e Mercosul', () {
    expect(placaValida('ABC1234'), isTrue);
    expect(placaValida('BRA2E19'), isTrue);
    expect(placaValida('AB12345'), isFalse);
  });

  test('máscaras', () {
    expect(mascaraCpf.aplicar('52998224725'), '529.982.247-25');
    expect(mascaraCep.aplicar('01310100'), '01310-100');
    expect(mascaraCep.aplicar('0131'), '0131');
  });

  test('números e datas', () {
    expect(formatarKm(1234567), '1.234.567');
    expect(formatarKm(999), '999');
    expect(formatarKm(-2000), '-2.000');
    expect(formatarReais(1234.5), r'R$ 1.234,50');
    expect(formatarData(DateTime(2026, 3, 7)), '07/03/2026');
    expect(lerValor('1.234,50'), 1234.5);
    expect(lerValor('280.5'), 280.5);
    expect(lerValor(''), isNull);
  });
}
