import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import '../util/sessao.dart';
import '../widgets/comuns.dart';

/// Entrada com CPF e senha.
class LoginTela extends StatefulWidget {
  const LoginTela({super.key, required this.aoEntrar, required this.aoCriarConta});

  final ValueChanged<Usuario> aoEntrar;
  final VoidCallback aoCriarConta;

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  final _form = GlobalKey<FormState>();
  final _cpf = TextEditingController();
  final _senha = TextEditingController();
  bool _entrando = false;
  String? _erro;

  @override
  void dispose() {
    _cpf.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() => _erro = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _entrando = true);
    final api = Servicos.of(context).api;
    try {
      final sessao = await api.entrar(somenteDigitos(_cpf.text), _senha.text);
      await Sessao.salvar(sessao.token);
      api.token = sessao.token;
      widget.aoEntrar(sessao.usuario);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  void _esqueci() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esqueceu a senha?'),
        content: const Text(
            'A recuperação de senha pelo app ainda está em construção. Por enquanto, fale com o suporte do Tok Mecânico.'),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Conteudo(
              larguraMaxima: 420,
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: LogoTok(altura: 150)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _cpf,
                    decoration: const InputDecoration(labelText: 'CPF', hintText: '000.000.000-00'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [mascaraCpf],
                    autofillHints: const [AutofillHints.username],
                    validator: (v) => cpfValido(v ?? '') ? null : 'CPF inválido',
                  ),
                  const SizedBox(height: 12),
                  CampoSenha(
                    controller: _senha,
                    rotulo: 'Senha',
                    validator: (v) => (v ?? '').isEmpty ? 'Informe a senha' : null,
                    aoEnviar: _entrar,
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(_erro!, style: TextStyle(color: cores.error), textAlign: TextAlign.center),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _esqueci, child: const Text('Esqueci minha senha')),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _entrando ? null : _entrar,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: _entrando
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: widget.aoCriarConta,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('Criar minha conta'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
