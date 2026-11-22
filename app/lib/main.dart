import 'package:material_ui/material_ui.dart';

import 'api/api_client.dart';
import 'api/cep_service.dart';
import 'api/modelos.dart';
import 'telas/cadastro_usuario_tela.dart';
import 'telas/login_tela.dart';
import 'telas/veiculos_tela.dart';
import 'util/sessao.dart';
import 'widgets/comuns.dart';

void main() {
  runApp(TokMecanicoApp(api: ApiClient(), cep: CepService()));
}

class TokMecanicoApp extends StatelessWidget {
  const TokMecanicoApp({super.key, required this.api, required this.cep});

  final ApiClient api;
  final CepService cep;

  @override
  Widget build(BuildContext context) {
    ThemeData tema(Brightness brilho) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0), brightness: brilho),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        );

    return Servicos(
      api: api,
      cep: cep,
      child: MaterialApp(
        title: 'Tok Mecânico',
        debugShowCheckedModeBanner: false,
        theme: tema(Brightness.light),
        darkTheme: tema(Brightness.dark),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Inicio(),
      ),
    );
  }
}

/// Decide entre login, cadastro e a lista de veículos.
class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  bool _carregando = true;
  bool _criandoConta = false;
  Usuario? _usuario;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    // Precisa do context (Servicos), então espera o primeiro frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final api = Servicos.of(context).api;
    api.aoPerderSessao = _sessaoExpirada;
    try {
      final token = await Sessao.token();
      Usuario? usuario;
      if (token != null) {
        api.token = token;
        try {
          usuario = await api.eu();
        } on ApiException catch (e) {
          if (e.status != 401) rethrow;
          await _limparSessao(); // token expirado ou inválido
        }
      }
      if (!mounted) return;
      setState(() {
        _usuario = usuario;
        _carregando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e;
          _carregando = false;
        });
      }
    }
  }

  Future<void> _limparSessao() async {
    await Sessao.sair();
    if (mounted) Servicos.of(context).api.token = null;
  }

  Future<void> _sair() async {
    await _limparSessao();
    if (mounted) setState(() => _usuario = null);
  }

  void _sessaoExpirada() {
    if (_usuario == null || !mounted) return;
    _sair();
    Navigator.of(context).popUntil((r) => r.isFirst);
    mostrarMensagem(context, 'Sua sessão expirou. Entre novamente.', erro: true);
  }

  void _entrou(Usuario u) => setState(() {
        _usuario = u;
        _criandoConta = false;
      });

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_erro != null) return Scaffold(body: ErroCarregar(erro: _erro!, tentarDeNovo: _carregar));

    final usuario = _usuario;
    if (usuario == null) {
      return _criandoConta
          ? CadastroUsuarioTela(aoConcluir: _entrou, aoIrParaLogin: () => setState(() => _criandoConta = false))
          : LoginTela(aoEntrar: _entrou, aoCriarConta: () => setState(() => _criandoConta = true));
    }
    return VeiculosTela(
      key: ValueKey(usuario.id),
      usuario: usuario,
      aoSair: _sair,
      aoAtualizarUsuario: (u) => setState(() => _usuario = u),
    );
  }
}
