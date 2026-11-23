import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import '../widgets/comuns.dart';

/// Histórico de manutenções realizadas, da mais recente para a mais antiga.
class HistoricoTela extends StatefulWidget {
  const HistoricoTela({super.key, required this.veiculo});

  final Veiculo veiculo;

  @override
  State<HistoricoTela> createState() => _HistoricoTelaState();
}

class _HistoricoTelaState extends State<HistoricoTela> {
  Future<List<Manutencao>>? _lista;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lista ??= Servicos.of(context).api.manutencoes(widget.veiculo.id);
  }

  void _recarregar() => setState(() => _lista = Servicos.of(context).api.manutencoes(widget.veiculo.id));

  Future<void> _excluir(Manutencao m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir revisão?'),
        content: Text('A revisão de ${formatarData(m.data)} (${formatarKm(m.km)} km) será apagada. '
            'Os itens dela voltam para a revisão anterior.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Servicos.of(context).api.excluirManutencao(widget.veiculo.id, m.id);
      if (!mounted) return;
      mostrarMensagem(context, 'Revisão excluída.');
      _recarregar();
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem, erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Histórico de revisões · ${widget.veiculo.placa}')),
      body: FutureBuilder<List<Manutencao>>(
        future: _lista,
        builder: (context, snap) {
          if (snap.hasError) return ErroCarregar(erro: snap.error!, tentarDeNovo: _recarregar);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(child: Text('Nenhuma manutenção registrada ainda.'));
          }
          final total = lista.fold<double>(0, (s, m) => s + (m.valor ?? 0));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Conteudo(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (total > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Total gasto: ${formatarReais(total)}', style: t.titleMedium),
                    ),
                  for (final m in lista)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text('${formatarData(m.data)} · ${formatarKm(m.km)} km',
                                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            if (m.valor != null) Text(formatarReais(m.valor!), style: t.titleSmall),
                            IconButton(
                              tooltip: 'Excluir revisão',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _excluir(m),
                            ),
                          ]),
                          if (m.itens.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final i in m.itens)
                                Chip(label: Text(i), visualDensity: VisualDensity.compact),
                            ]),
                          ],
                          if (m.descricao != null) ...[const SizedBox(height: 8), Text(m.descricao!)],
                          if (m.oficina != null) ...[
                            const SizedBox(height: 4),
                            Text(m.oficina!, style: t.bodySmall),
                          ],
                        ]),
                      ),
                    ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
