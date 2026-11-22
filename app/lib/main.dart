import 'package:material_ui/material_ui.dart';

import 'api/api_client.dart';
import 'api/cep_service.dart';
import 'api/modelos.dart';
import 'telas/cadastro_usuario_tela.dart';
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

/// Decide entre o cadastro (primeiro acesso) e a lista de veículos.
class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  bool _carregando = true;
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
    try {
      final id = await Sessao.usuarioId();
      Usuario? usuario;
      if (id != null) {
        try {
          usuario = await api.usuario(id);
        } on ApiException catch (e) {
          if (e.status != 404) rethrow;
          await Sessao.sair(); // cadastro não existe mais no servidor
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

  Future<void> _sair() async {
    await Sessao.sair();
    if (mounted) setState(() => _usuario = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_erro != null) return Scaffold(body: ErroCarregar(erro: _erro!, tentarDeNovo: _carregar));

    final usuario = _usuario;
    if (usuario == null) {
      return CadastroUsuarioTela(aoConcluir: (u) => setState(() => _usuario = u));
    }
    return VeiculosTela(
      key: ValueKey(usuario.id),
      usuario: usuario,
      aoSair: _sair,
      aoAtualizarUsuario: (u) => setState(() => _usuario = u),
    );
  }
}
