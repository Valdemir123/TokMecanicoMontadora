import 'dart:convert';

import 'package:http/http.dart' as http;

import 'modelos.dart';

/// Endereço da API. Troque ao rodar: `flutter run --dart-define=API_URL=https://...`
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5153');

/// Erro devolvido pela API. [campos] traz as mensagens por campo (ex.: "cpf", "enderecoResidencial.cep").
class ApiException implements Exception {
  ApiException(this.mensagem, {this.campos = const {}, this.status});

  final String mensagem;
  final Map<String, List<String>> campos;
  final int? status;

  String? erroDe(String campo) => campos[campo]?.join(' ');

  @override
  String toString() => mensagem;
}

class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = apiUrl}) : _http = client ?? http.Client();

  final http.Client _http;
  final String baseUrl;

  /// Token do usuário logado; enviado em todas as chamadas.
  String? token;

  /// Chamado quando a API recusa o token (expirado ou inválido) para o app voltar ao login.
  void Function()? aoPerderSessao;

  // ---------- Catálogos ----------

  Future<List<Fabricante>> fabricantes() async =>
      (await _get('/api/fabricantes') as List).map((e) => Fabricante.fromJson(e)).toList();

  // ---------- Login e usuário ----------

  Future<SessaoUsuario> cadastrar(Map<String, dynamic> dados) async =>
      SessaoUsuario.fromJson(await _send('POST', '/api/auth/cadastro', dados));

  Future<SessaoUsuario> entrar(String cpf, String senha) async =>
      SessaoUsuario.fromJson(await _send('POST', '/api/auth/login', {'cpf': cpf, 'senha': senha}));

  Future<Usuario> eu() async => Usuario.fromJson(await _get('/api/usuarios/me'));

  Future<Usuario> atualizarUsuario(Map<String, dynamic> dados) async =>
      Usuario.fromJson(await _send('PUT', '/api/usuarios/me', dados));

  Future<void> trocarSenha(String atual, String nova) =>
      _send('POST', '/api/usuarios/me/senha', {'senhaAtual': atual, 'novaSenha': nova});

  // ---------- Veículos ----------

  Future<List<Veiculo>> veiculos() async =>
      (await _get('/api/veiculos') as List).map((e) => Veiculo.fromJson(e)).toList();

  Future<Veiculo> criarVeiculo(Map<String, dynamic> dados) async =>
      Veiculo.fromJson(await _send('POST', '/api/veiculos', dados));

  Future<Veiculo> atualizarVeiculo(String id, Map<String, dynamic> dados) async =>
      Veiculo.fromJson(await _send('PUT', '/api/veiculos/$id', dados));

  Future<void> excluirVeiculo(String id) => _send('DELETE', '/api/veiculos/$id');

  Future<Painel> painel(String veiculoId) async =>
      Painel.fromJson(await _get('/api/veiculos/$veiculoId/painel'));

  // ---------- Itens, km e manutenções ----------

  Future<void> criarItem(String veiculoId, Map<String, dynamic> dados) =>
      _send('POST', '/api/veiculos/$veiculoId/itens', dados);

  Future<void> atualizarItem(String veiculoId, String itemId, Map<String, dynamic> dados) =>
      _send('PUT', '/api/veiculos/$veiculoId/itens/$itemId', dados);

  Future<void> excluirItem(String veiculoId, String itemId) =>
      _send('DELETE', '/api/veiculos/$veiculoId/itens/$itemId');

  Future<void> registrarKm(String veiculoId, int km, DateTime data) =>
      _send('POST', '/api/veiculos/$veiculoId/km', {'km': km, 'data': dataIso(data)});

  Future<List<Manutencao>> manutencoes(String veiculoId) async =>
      (await _get('/api/veiculos/$veiculoId/manutencoes') as List)
          .map((e) => Manutencao.fromJson(e))
          .toList();

  Future<void> registrarManutencao(String veiculoId, Map<String, dynamic> dados) =>
      _send('POST', '/api/veiculos/$veiculoId/manutencoes', dados);

  // ---------- HTTP ----------

  Future<dynamic> _get(String caminho) => _send('GET', caminho);

  Future<dynamic> _send(String metodo, String caminho, [Map<String, dynamic>? corpo]) async {
    final req = http.Request(metodo, Uri.parse('$baseUrl$caminho'))
      ..headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (corpo != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(corpo);
    }

    final http.Response resp;
    try {
      resp = await http.Response.fromStream(await _http.send(req));
    } catch (_) {
      throw ApiException('Não foi possível conectar ao servidor. Verifique sua conexão.');
    }

    final texto = utf8.decode(resp.bodyBytes);
    final json = texto.isEmpty ? null : jsonDecode(texto);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return json;
    // 401 fora do login = token expirado/inválido: volta para a tela de login.
    if (resp.statusCode == 401 && token != null && !caminho.startsWith('/api/auth/')) aoPerderSessao?.call();
    if (resp.statusCode == 429) {
      throw ApiException('Muitas tentativas. Aguarde um minuto e tente de novo.', status: 429);
    }

    throw _erro(resp.statusCode, json);
  }

  ApiException _erro(int status, dynamic json) {
    if (json is Map<String, dynamic>) {
      final campos = <String, List<String>>{};
      final errors = json['errors'];
      if (errors is Map<String, dynamic>) {
        errors.forEach((k, v) => campos[k] = List<String>.from(v as List));
      }
      final mensagem = json['mensagem'] as String? ??
          (campos.isNotEmpty ? 'Confira os campos destacados.' : json['title'] as String?);
      if (mensagem != null) return ApiException(mensagem, campos: campos, status: status);
    }
    if (status == 404) return ApiException('Registro não encontrado.', status: status);
    return ApiException('Erro inesperado no servidor ($status).', status: status);
  }
}
