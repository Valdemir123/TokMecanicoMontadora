import 'package:material_ui/material_ui.dart';

import '../api/modelos.dart';
import '../util/formatos.dart';
import '../widgets/comuns.dart';
import 'cadastro_usuario_tela.dart';
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

  Future<List<Veiculo>> _carregar() => Servicos.of(context).api.veiculos(widget.usuario.id);

  void _recarregar() => setState(() => _veiculos = _carregar());

  Future<void> _novoVeiculo() async {
    final criado = await Navigator.of(context).push<Veiculo>(
      MaterialPageRoute(builder: (_) => VeiculoFormTela(usuarioId: widget.usuario.id)),
    );
    if (criado == null || !mounted) return;
    _recarregar();
    _abrirPainel(criado);
  }

  Future<void> _abrirPainel(Veiculo v) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PainelTela(veiculoId: v.id)));
    if (mounted) _recarregar();
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
        title: const Text('Tok Mecânico'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (op) => op == 'dados' ? _meusDados() : widget.aoSair(),
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(widget.usuario.nomeCompleto)),
              const PopupMenuItem(value: 'dados', child: Text('Meus dados')),
              const PopupMenuItem(value: 'sair', child: Text('Sair deste aparelho')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoVeiculo,
        icon: const Icon(Icons.add),
        label: const Text('Veículo'),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Conteudo(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Olá, ${widget.usuario.primeiroNome}!',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Seus veículos'),
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
            Icon(Icons.directions_car, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            const Text('Nenhum veículo cadastrado ainda.', textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text('Cadastre seu veículo para acompanhar as manutenções.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: aoAdicionar, icon: const Icon(Icons.add), label: const Text('Cadastrar veículo')),
          ]),
        ),
      );
}
