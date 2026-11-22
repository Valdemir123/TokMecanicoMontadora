import 'dart:convert';

import 'package:http/http.dart' as http;

class EnderecoCep {
  EnderecoCep({required this.logradouro, required this.bairro, required this.cidade, required this.uf});

  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;
}

/// Busca o endereço de um CEP no ViaCEP (serviço público e gratuito).
class CepService {
  CepService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  /// Retorna null se o CEP não existir ou se a consulta falhar
  /// (nesse caso o usuário preenche o endereço manualmente).
  Future<EnderecoCep?> buscar(String cep) async {
    final digitos = cep.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 8) return null;
    try {
      final resp = await _http
          .get(Uri.parse('https://viacep.com.br/ws/$digitos/json/'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (j['erro'] != null) return null;
      return EnderecoCep(
        logradouro: j['logradouro'] ?? '',
        bairro: j['bairro'] ?? '',
        cidade: j['localidade'] ?? '',
        uf: j['uf'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
