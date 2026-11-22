import 'package:shared_preferences/shared_preferences.dart';

/// Guarda no aparelho o token de acesso devolvido pelo login.
class Sessao {
  static const _chave = 'token';

  static Future<String?> token() async => (await SharedPreferences.getInstance()).getString(_chave);

  static Future<void> salvar(String token) async =>
      (await SharedPreferences.getInstance()).setString(_chave, token);

  static Future<void> sair() async => (await SharedPreferences.getInstance()).remove(_chave);
}
