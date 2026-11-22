import 'package:shared_preferences/shared_preferences.dart';

/// Guarda no aparelho o id do usuário cadastrado.
/// Provisório até existir login (e-mail/senha ou código por SMS).
class Sessao {
  static const _chave = 'usuarioId';

  static Future<String?> usuarioId() async => (await SharedPreferences.getInstance()).getString(_chave);

  static Future<void> salvar(String id) async =>
      (await SharedPreferences.getInstance()).setString(_chave, id);

  static Future<void> sair() async => (await SharedPreferences.getInstance()).remove(_chave);
}
