import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import '../widgets/comuns.dart';
import 'cadastro_usuario_tela.dart';
import 'conferencia_tela.dart';
import 'painel_tela.dart';
import 'veiculo_form_tela.dart';

/// Tela inicial: veículos do usuário.
class VeiculosTela extends StatefulWidget {
  const VeiculosTela({super.key, required this.usuario, required this.aoSair, required this.aoAtualizarUsuario});

  final Usuario usuario;
  final VoidCallback aoSair;
  final ValueChanged<Usuario> aoAtualizarUsuario;

  @override
  State<VeiculosTela> createState() => _VeiculosTelaState();
}

class _VeiculosTelaState extends State<VeiculosTela> {
  Future<List<Veiculo>>? _veiculos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _veiculos ??= _carregar();
  }

  Future<List<Veiculo>> _carregar() => Servicos.of(context).api.veiculos();

  void _recarregar() => setState(() => _veiculos = _carregar());

  Future<void> _novoVeiculo() async {
    final criado = await Navigator.of(context).push<Veiculo>(
      MaterialPageRoute(builder: (_) => const VeiculoFormTela()),
    );
    if (criado == null || !mounted) return;
    // O usuário confere os itens pré-preenchidos pela data de referência.
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConferenciaTela(veiculo: criado)));
    if (!mounted) return;
    // Volta para a lista já atualizada; o usuário escolhe o veículo para ver as manutenções.
    _recarregar();
    mostrarMensagem(context, 'Veículo cadastrado! Toque nele para ver as manutenções.');
  }

  Future<void> _abrirPainel(Veiculo v) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PainelTela(veiculoId: v.id)));
    if (mounted) _recarregar();
  }

  Future<void> _trocarSenha() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _DialogoTrocaSenha());
    if (ok == true && mounted) mostrarMensagem(context, 'Senha alterada.');
  }

  void _meusDados() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => CadastroUsuarioTela(
        usuario: widget.usuario,
        aoConcluir: (u) {
          widget.aoAtualizarUsuario(u);
          Navigator.of(ctx).pop();
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          LogoTok(altura: 32, soSimbolo: true),
          SizedBox(width: 10),
          Text('Tok Mecânico'),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (op) => switch (op) {
              'dados' => _meusDados(),
              'sobre' => mostrarSobre(context),
              'senha' => _trocarSenha(),
              _ => widget.aoSair(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(widget.usuario.nomeCompleto)),
              const PopupMenuItem(value: 'dados', child: Text('Meus dados')),
              const PopupMenuItem(value: 'senha', child: Text('Trocar senha')),
              const PopupMenuItem(value: 'sobre', child: Text('Sobre o Tok Mecânico')),
              const PopupMenuItem(value: 'sair', child: Text('Sair')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Veiculo>>(
        future: _veiculos,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return ErroCarregar(erro: snap.error!, tentarDeNovo: _recarregar);

          final veiculos = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _recarregar(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Conteudo(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Olá, ${widget.usuario.primeiroNome}!',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Seus veículos'),
                    if (veiculos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Icon(Icons.touch_app, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Selecione o veículo para ver os detalhes das manutenções.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    if (veiculos.isEmpty) _Vazio(aoAdicionar: _novoVeiculo),
                    for (final v in veiculos)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: LogoMontadora(v.assetLogo, tamanho: 48),
                          title: Text('${v.fabricante} ${v.modelo}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${v.placa} · ${v.anoFabricacao} · ${v.cor}\n'
                              '${formatarKm(v.kmAtual)} km'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _abrirPainel(v),
                        ),
                      ),
                    // botão junto da lista (no lugar do botão flutuante no canto da tela)
                    if (veiculos.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: _novoVeiculo,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar veículo'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.aoAdicionar});

  final VoidCallback aoAdicionar;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Mascote(altura: 180),
            const SizedBox(height: 12),
            Text('Vamos começar?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text('Cadastre seu veículo e eu aviso quando cada manutenção estiver chegando.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: aoAdicionar, icon: const Icon(Icons.add), label: const Text('Cadastrar veículo')),
          ]),
        ),
      );
}

class _DialogoTrocaSenha extends StatefulWidget {
  const _DialogoTrocaSenha();

  @override
  State<_DialogoTrocaSenha> createState() => _DialogoTrocaSenhaState();
}

class _DialogoTrocaSenhaState extends State<_DialogoTrocaSenha> {
  final _form = GlobalKey<FormState>();
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  ApiException? _erro;
  bool _salvando = false;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await Servicos.of(context).api.trocarSenha(_atual.text, _nova.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Trocar senha'),
        content: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CampoSenha(controller: _atual, rotulo: 'Senha atual', erroApi: _erro?.erroDe('senhaAtual'),
                validator: (v) => (v ?? '').isEmpty ? 'Informe a senha atual' : null),
            const SizedBox(height: 12),
            CampoSenha(controller: _nova, rotulo: 'Nova senha', erroApi: _erro?.erroDe('novaSenha'),
                validator: problemaSenha),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: _salvando ? null : _salvar, child: const Text('Salvar')),
        ],
      );
}
