import 'package:flutter/services.dart';

String somenteDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Aplica uma máscara onde '#' é um dígito (ex.: '###.###.###-##').
class MascaraDigitos extends TextInputFormatter {
  MascaraDigitos(this.mascara) : _max = '#'.allMatches(mascara).length;

  final String mascara;
  final int _max;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitos = somenteDigitos(newValue.text);
    final limitado = digitos.length > _max ? digitos.substring(0, _max) : digitos;
    final texto = aplicar(limitado);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }

  String aplicar(String digitos) {
    final b = StringBuffer();
    var i = 0;
    for (final c in mascara.split('')) {
      if (i >= digitos.length) break;
      if (c == '#') {
        b.write(digitos[i++]);
      } else {
        b.write(c);
      }
    }
    return b.toString();
  }
}

final mascaraCpf = MascaraDigitos('###.###.###-##');
final mascaraCep = MascaraDigitos('#####-###');
final mascaraTelefone = MascaraDigitos('(##) #####-####');

/// Placa: letras maiúsculas e números, máximo 7 caracteres (ABC1234 ou ABC1D23).
class MascaraPlaca extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var t = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (t.length > 7) t = t.substring(0, 7);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

bool cpfValido(String cpf) {
  final d = somenteDigitos(cpf);
  if (d.length != 11 || d.split('').toSet().length == 1) return false;
  int digito(int tamanho) {
    var soma = 0;
    for (var i = 0; i < tamanho; i++) {
      soma += int.parse(d[i]) * (tamanho + 1 - i);
    }
    final resto = soma % 11;
    return resto < 2 ? 0 : 11 - resto;
  }

  return digito(9) == int.parse(d[9]) && digito(10) == int.parse(d[10]);
}

bool placaValida(String placa) => RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$').hasMatch(placa);

/// 12345 -> "12.345"
String formatarKm(int km) {
  final s = km.abs().toString();
  final b = StringBuffer(km < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// DateTime -> "22/11/2026"
String formatarData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// 1234.5 -> "R$ 1.234,50"
String formatarReais(double v) {
  final centavos = (v * 100).round();
  return 'R\$ ${formatarKm(centavos ~/ 100)},${(centavos % 100).toString().padLeft(2, '0')}';
}

/// "1.234,50" ou "1234.50" -> 1234.5
double? lerValor(String texto) {
  var t = texto.replaceAll(RegExp(r'[^0-9,.]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

/// Mesmas regras da API: 8+ caracteres, com letras e números.
String? problemaSenha(String? senha) {
  if (senha == null || senha.length < 8) return 'Mínimo de 8 caracteres';
  if (!senha.contains(RegExp(r'[A-Za-zÀ-ÿ]')) || !senha.contains(RegExp(r'\d'))) return 'Use letras e números';
  return null;
}
