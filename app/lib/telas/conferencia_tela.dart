import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import '../widgets/comuns.dart';

/// Logo após cadastrar o veículo: o usuário confere quais manutenções foram feitas
/// na data de referência (aquisição ou última revisão). Desmarcadas ficam "sem registro".
class ConferenciaTela extends StatefulWidget {
  const ConferenciaTela({super.key, required this.veiculo});

  final Veiculo veiculo;

  @override
  State<ConferenciaTela> createState() => _ConferenciaTelaState();
}

class _ConferenciaTelaState extends State<ConferenciaTela> {
  Future<Painel>? _painel;
  final _naoFeitos = <String>{};
  bool _salvando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _painel ??= Servicos.of(context).api.painel(widget.veiculo.id);
  }

  Future<void> _confirmar() async {
    setState(() => _salvando = true);
    try {
      if (_naoFeitos.isNotEmpty) {
        await Servicos.of(context).api.conferirItens(widget.veiculo.id, _naoFeitos.toList());
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confira as manutenções'), automaticallyImplyLeading: false),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Conteudo(
            child: FilledButton.icon(
              onPressed: _salvando ? null : _confirmar,
              icon: _salvando
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('Confirmar'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
        ),
      ),
      body: FutureBuilder<Painel>(
        future: _painel,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErroCarregar(
              erro: snap.error!,
              tentarDeNovo: () => setState(() => _painel = Servicos.of(context).api.painel(widget.veiculo.id)),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final itens = [...snap.data!.itens]..sort((a, b) => a.nome.compareTo(b.nome));
          final ref = itens.map((i) => i.ultimaData).whereType<DateTime>().firstOrNull;
          final kmRef = itens.map((i) => i.ultimaKm).whereType<int>().firstOrNull;

          if (ref == null) {
            // Sem data de referência: nada pré-preenchido para conferir.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
            return const SizedBox.shrink();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Conteudo(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  RecadoMascote(
                    titulo: 'Quase pronto!',
                    texto: 'Marcamos todas as manutenções como feitas em ${formatarData(ref)}'
                        '${kmRef == null ? '' : ' (${formatarKm(kmRef)} km)'}. '
                        'Desmarque o que não foi feito nessa data.',
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(children: [
                      for (final i in itens)
                        CheckboxListTile(
                          value: !_naoFeitos.contains(i.id),
                          onChanged: (feito) =>
                              setState(() => feito == true ? _naoFeitos.remove(i.id) : _naoFeitos.add(i.id)),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(i.nome),
                          subtitle: Text(_naoFeitos.contains(i.id) ? 'Não foi feito nessa data' : _proxima(i)),
                          secondary: _naoFeitos.contains(i.id) ? null : SeloSituacao(i.situacao),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text('Você pode ajustar cada item depois, no painel do veículo.',
                      style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _proxima(ItemManutencao i) {
    final partes = [
      if (i.proximaKm != null) '${formatarKm(i.proximaKm!)} km',
      if (i.proximaData != null) formatarData(i.proximaData!),
    ];
    return partes.isEmpty ? '' : 'Próxima: ${partes.join(' ou ')}';
  }
}
