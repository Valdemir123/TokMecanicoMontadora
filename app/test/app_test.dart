import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/api/cep_service.dart';
import 'package:app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _usuario = {
  'id': 'u1',
  'cpf': '52998224725',
  'nomeCompleto': 'Maria da Silva',
  'email': null,
  'telefone': null,
  'enderecoResidencial': {
    'cep': '01310100', 'logradouro': 'Av. Paulista', 'numero': '1000', 'complemento': null,
    'bairro': 'Bela Vista', 'cidade': 'São Paulo', 'uf': 'SP',
  },
  'enderecoTrabalho': null,
  'criadoEm': '2026-11-22T12:00:00Z',
};

const _veiculo = {
  'id': 'v1', 'usuarioId': 'u1', 'placa': 'BRA2E19', 'fabricante': 'Fiat', 'fabricanteLogo': 'imgFiat.png',
  'modelo': 'Argo 1.0', 'anoFabricacao': 2021, 'cor': 'Prata', 'kmAtual': 52000, 'dataKmAtual': '2026-11-22',
};

Map<String, dynamic> _item(String id, String nome, String situacao, {int? kmRestante}) => {
      'id': id, 'codigoCatalogo': null, 'nome': nome, 'observacao': null, 'personalizado': false,
      'intervaloKm': 10000, 'intervaloMeses': 12, 'ultimaKm': null, 'ultimaData': null,
      'situacao': situacao, 'proximaKm': null, 'kmRestante': kmRestante, 'proximaData': null, 'diasRestantes': null,
    };

const _token = 'token-valido';

/// API falsa: exige o token nas rotas protegidas e aceita a senha "segredo123".
MockClient _apiFalsa() => MockClient((req) async {
      http.Response json(Object corpo, [int status = 200]) => http.Response(jsonEncode(corpo), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

      if (req.url.path == '/api/auth/login') {
        final dados = jsonDecode(req.body) as Map<String, dynamic>;
        return dados['senha'] == 'segredo123'
            ? json({'token': _token, 'expiraEm': '2026-12-22T00:00:00Z', 'usuario': _usuario})
            : json({'mensagem': 'CPF ou senha incorretos.'}, 401);
      }
      if (req.headers['Authorization'] != 'Bearer $_token') return http.Response('', 401);

      final rotas = <String, Object>{
        '/api/usuarios/me': _usuario,
        '/api/veiculos': [_veiculo],
        '/api/veiculos/v1/painel': {
          'veiculo': _veiculo, 'vencidos': 1, 'proximos': 0, 'semRegistro': 1,
          'itens': [
            _item('i1', 'Troca de óleo do motor', 'Vencido', kmRestante: -2000),
            _item('i2', 'Bateria', 'SemRegistro'),
          ],
        },
      };
      final corpo = rotas[req.url.path];
      return corpo == null ? http.Response('', 404) : json(corpo);
    });

Widget _app() => TokMecanicoApp(
      api: ApiClient(client: _apiFalsa(), baseUrl: 'http://api'),
      cep: CepService(client: MockClient((_) async => http.Response('{"erro": true}', 200))),
    );

Future<void> _digitar(WidgetTester tester, String rotulo, String texto) =>
    tester.enterText(find.widgetWithText(TextFormField, rotulo), texto);

void main() {
  testWidgets('sem login abre a tela de entrada; "Criar minha conta" abre o cadastro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.bySemanticsLabel('Tok Mecânico'), findsOneWidget);

    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo!'), findsOneWidget);

    await _digitar(tester, 'CPF', '12345678900');
    await _digitar(tester, 'Senha', 'curta');
    await tester.ensureVisible(find.text('Concluir cadastro'));
    await tester.tap(find.text('Concluir cadastro'));
    await tester.pumpAndSettle();

    expect(find.text('CPF inválido'), findsOneWidget);
    expect(find.text('Informe o nome completo'), findsOneWidget);
    expect(find.text('Mínimo de 8 caracteres'), findsOneWidget);
  });

  testWidgets('senha errada mostra erro; senha certa entra e guarda o token', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _digitar(tester, 'CPF', '52998224725');
    await _digitar(tester, 'Senha', 'errada123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('CPF ou senha incorretos.'), findsOneWidget);

    await _digitar(tester, 'Senha', 'segredo123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Maria!'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('token'), _token);
  });

  testWidgets('token expirado volta para o login', (tester) async {
    SharedPreferences.setMockInitialValues({'token': 'token-velho'});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('token'), isNull);
  });

  testWidgets('usuário logado vê seus veículos e o painel de manutenções', (tester) async {
    SharedPreferences.setMockInitialValues({'token': _token});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Olá, Maria!'), findsOneWidget);
    expect(find.text('Fiat Argo 1.0'), findsOneWidget);
    expect(find.text('Selecione o veículo para ver os detalhes das manutenções.'), findsOneWidget);

    await tester.tap(find.text('Fiat Argo 1.0'));
    await tester.pumpAndSettle();

    expect(find.text('52.000 km'), findsOneWidget);
    expect(find.text('Troca de óleo do motor'), findsOneWidget);
    expect(find.text('passou 2.000 km'), findsOneWidget);
    expect(find.text('1 item vencido!'), findsOneWidget);
    expect(find.text('Vencido'), findsOneWidget);
    expect(find.text('Sem registro'), findsNWidgets(2)); // contador + selo do item
  });
}
