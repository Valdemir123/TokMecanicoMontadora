import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import '../util/sessao.dart';
import '../widgets/comuns.dart';
import '../widgets/endereco_form.dart';

/// Cadastro (ou edição, se [usuario] for informado) dos dados do usuário.
class CadastroUsuarioTela extends StatefulWidget {
  const CadastroUsuarioTela({super.key, this.usuario, this.aoConcluir});

  final Usuario? usuario;
  final ValueChanged<Usuario>? aoConcluir;

  @override
  State<CadastroUsuarioTela> createState() => _CadastroUsuarioTelaState();
}

class _CadastroUsuarioTelaState extends State<CadastroUsuarioTela> {
  final _form = GlobalKey<FormState>();
  final _cpf = TextEditingController();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _residencial = EnderecoControles();
  final _trabalho = EnderecoControles();

  bool _salvando = false;
  ApiException? _erro;

  bool get _editando => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    if (u != null) {
      _cpf.text = mascaraCpf.aplicar(u.cpf);
      _nome.text = u.nomeCompleto;
      _email.text = u.email ?? '';
      _telefone.text = u.telefone == null ? '' : mascaraTelefone.aplicar(u.telefone!);
      _residencial.preencher(u.enderecoResidencial);
      _trabalho.preencher(u.enderecoTrabalho);
    }
  }

  @override
  void dispose() {
    for (final c in [_cpf, _nome, _email, _telefone]) {
      c.dispose();
    }
    _residencial.dispose();
    _trabalho.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_form.currentState!.validate()) return;

    final dados = {
      'cpf': somenteDigitos(_cpf.text),
      'nomeCompleto': _nome.text.trim(),
      'email': _email.text.trim(),
      'telefone': somenteDigitos(_telefone.text),
      'enderecoResidencial': _residencial.toJson(),
      'enderecoTrabalho': _trabalho.vazio ? null : _trabalho.toJson(),
    };

    setState(() => _salvando = true);
    final api = Servicos.of(context).api;
    try {
      final usuario = _editando
          ? await api.atualizarUsuario(widget.usuario!.id, dados)
          : await api.criarUsuario(dados);
      if (!_editando) await Sessao.salvar(usuario.id);
      if (!mounted) return;
      mostrarMensagem(context, _editando ? 'Dados atualizados.' : 'Cadastro concluído!');
      widget.aoConcluir?.call(usuario);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e);
      mostrarMensagem(context, e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Meus dados' : 'Cadastro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Conteudo(
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!_editando) ...[
                const Center(child: LogoTok(altura: 150)),
                const SizedBox(height: 24),
                Text('Bem-vindo!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Cadastre-se para controlar as manutenções do seu veículo.',
                    style: TextStyle(color: cores.onSurfaceVariant)),
              ],
              const TituloSecao('Seus dados'),
              LinhaResponsiva(flex: const [2, 3], children: [
                TextFormField(
                  controller: _cpf,
                  enabled: !_editando,
                  decoration: InputDecoration(
                    labelText: 'CPF',
                    hintText: '000.000.000-00',
                    errorText: _erro?.erroDe('cpf'),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [mascaraCpf],
                  validator: (v) => cpfValido(v ?? '') ? null : 'CPF inválido',
                ),
                TextFormField(
                  controller: _nome,
                  decoration: InputDecoration(labelText: 'Nome completo', errorText: _erro?.erroDe('nomeCompleto')),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    final n = (v ?? '').trim();
                    if (n.isEmpty) return 'Informe o nome completo';
                    if (!n.contains(' ')) return 'Informe nome e sobrenome';
                    return null;
                  },
                ),
              ]),
              const SizedBox(height: 12),
              LinhaResponsiva(children: [
                TextFormField(
                  controller: _email,
                  decoration: InputDecoration(labelText: 'E-mail (opcional)', errorText: _erro?.erroDe('email')),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty || (v ?? '').contains('@') ? null : 'E-mail inválido',
                ),
                TextFormField(
                  controller: _telefone,
                  decoration: const InputDecoration(labelText: 'Celular (opcional)', hintText: '(00) 00000-0000'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [mascaraTelefone],
                ),
              ]),
              const TituloSecao('Endereço residencial'),
              EnderecoForm(controles: _residencial, prefixoErro: 'enderecoResidencial', erroApi: _erro),
              const TituloSecao('Endereço de trabalho',
                  subtitulo: 'Opcional. Ajuda a encontrar oficinas e lojas perto de onde você passa o dia.'),
              EnderecoForm(
                controles: _trabalho,
                prefixoErro: 'enderecoTrabalho',
                erroApi: _erro,
                obrigatorio: false,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_editando ? 'Salvar alterações' : 'Concluir cadastro'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }
}
