import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import '../widgets/comuns.dart';
import '../widgets/linha_do_tempo.dart';
import 'historico_tela.dart';
import 'item_form_tela.dart';
import 'manutencao_form_tela.dart';
import 'veiculo_form_tela.dart';

/// Painel de manutenções de um veículo: o que está vencido, próximo e em dia.
class PainelTela extends StatefulWidget {
  const PainelTela({super.key, required this.veiculoId});

  final String veiculoId;

  @override
  State<PainelTela> createState() => _PainelTelaState();
}

class _PainelTelaState extends State<PainelTela> {
  Future<Painel>? _painel;

  /// Item recém-alterado: fica destacado por alguns segundos e a tela rola até ele.
  String? _destaque;
  final _chaves = <String, GlobalKey>{};
  Timer? _timerDestaque;

  @override
  void dispose() {
    _timerDestaque?.cancel();
    super.dispose();
  }

  ApiClient get _api => Servicos.of(context).api;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _painel ??= _api.painel(widget.veiculoId);
  }

  void _recarregar() => setState(() => _painel = _api.painel(widget.veiculoId));

  /// Abre uma tela do painel e sempre recarrega ao voltar (salvou ou não).
  Future<Object?> _abrir(Widget tela) async {
    final resultado = await Navigator.of(context).push<Object>(MaterialPageRoute(builder: (_) => tela));
    if (mounted) _recarregar();
    return resultado;
  }

  Future<void> _abrirItem(String veiculoId, [ItemManutencao? item]) async {
    final r = await _abrir(ItemFormTela(veiculoId: veiculoId, item: item));
    if (!mounted) return;
    if (r is ItemManutencao) {
      mostrarMensagem(context, _confirmacao(r));
      _destacar(r.id);
    } else if (r == ItemFormTela.removido) {
      mostrarMensagem(context, '"${item?.nome}" removido.');
    }
  }

  void _destacar(String id) {
    _timerDestaque?.cancel();
    setState(() => _destaque = id);
    // espera o painel recarregar e rola até o item
    _painel?.then((_) => WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _chaves[id]?.currentContext;
          if (ctx != null && ctx.mounted) {
            Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), alignment: 0.3);
          }
        }));
    _timerDestaque = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _destaque = null);
    });
  }

  static String _confirmacao(ItemManutencao i) {
    final proxima = [
      if (i.proximaKm != null) '${formatarKm(i.proximaKm!)} km',
      if (i.proximaData != null) formatarData(i.proximaData!),
    ];
    final quando = proxima.isEmpty ? '' : ' Próxima: ${proxima.join(i.referencia == Referencia.ambos ? ' ou ' : '')}.';
    return '${i.nome}: ${i.situacao.rotulo.toLowerCase()} (${i.referencia.rotulo.toLowerCase()}).$quando';
  }

  Future<void> _registrarKm(Veiculo v) async {
    final km = await showDialog<int>(context: context, builder: (_) => _DialogoKm(kmAtual: v.kmAtual));
    if (km == null || !mounted) return;
    try {
      await _api.registrarKm(v.id, km, DateTime.now());
      if (!mounted) return;
      mostrarMensagem(context, 'Km atualizado para ${formatarKm(km)} km.');
      _recarregar();
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.erroDe('km') ?? e.mensagem, erro: true);
    }
  }

  Future<void> _editarVeiculo(Veiculo v) async {
    final salvo = await Navigator.of(context).push<Veiculo>(
      MaterialPageRoute(builder: (_) => VeiculoFormTela(veiculo: v)),
    );
    if (salvo != null && mounted) _recarregar();
  }

  Future<void> _excluirVeiculo(Veiculo v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir veículo?'),
        content: Text('O ${v.modelo} (${v.placa}) e todo o histórico de manutenções serão apagados.'),
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
      await _api.excluirVeiculo(v.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem, erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Painel>(
      future: _painel,
      builder: (context, snap) {
        final p = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(p == null ? 'Manutenções' : '${p.veiculo.modelo} · ${p.veiculo.placa}'),
            actions: [
              if (p != null) ...[
                IconButton(
                  tooltip: 'Histórico',
                  icon: const Icon(Icons.history),
                  onPressed: () => _abrir(HistoricoTela(veiculo: p.veiculo)),
                ),
                PopupMenuButton<String>(
                  onSelected: (op) => switch (op) {
                    'editar' => _editarVeiculo(p.veiculo),
                    'item' => _abrirItem(p.veiculo.id),
                    _ => _excluirVeiculo(p.veiculo),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'item', child: Text('Novo item pessoal')),
                    PopupMenuItem(value: 'editar', child: Text('Editar veículo')),
                    PopupMenuItem(value: 'excluir', child: Text('Excluir veículo')),
                  ],
                ),
              ],
            ],
          ),
          body: switch (snap) {
            AsyncSnapshot(hasError: true, :final error?) => ErroCarregar(erro: error, tentarDeNovo: _recarregar),
            AsyncSnapshot(:final data?) => RefreshIndicator(
                onRefresh: () async => _recarregar(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [Conteudo(child: _corpo(data))],
                ),
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }

  Widget _corpo(Painel p) {
    final v = p.veiculo;
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            LogoMontadora(v.assetLogo, tamanho: 56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${v.fabricante} ${v.modelo}', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text('${v.anoFabricacao} · ${v.cor}'),
                const SizedBox(height: 8),
                Text('${formatarKm(v.kmAtual)} km', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                if (v.dataKmAtual != null) Text('atualizado em ${formatarData(v.dataKmAtual!)}', style: t.bodySmall),
              ]),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _registrarKm(v),
              icon: const Icon(Icons.speed),
              label: const Text('Km'),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => _abrir(ManutencaoFormTela(veiculo: p.veiculo, itens: p.itens, kmPorMes: p.kmPorMes)),
        icon: const Icon(Icons.build),
        label: const Text('Registrar revisão periódica'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: const TextStyle(fontSize: 16)),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _abrir(HistoricoTela(veiculo: p.veiculo)),
        icon: const Icon(Icons.history),
        label: const Text('Histórico de revisões'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
      ),
      if (_proximaRevisao(p) case final proxima?) ...[
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: const Icon(Icons.event_repeat),
            title: const Text('Próxima revisão', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(proxima),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Row(children: [
        _Contador(rotulo: 'Vencidos', valor: p.vencidos, situacao: Situacao.vencido),
        const SizedBox(width: 8),
        _Contador(rotulo: 'Próximos', valor: p.proximos, situacao: Situacao.proximo),
        const SizedBox(width: 8),
        _Contador(rotulo: 'Sem registro', valor: p.semRegistro, situacao: Situacao.semRegistro),
      ]),
      const SizedBox(height: 12),
      _recado(p),
      if (p.itens.any((i) => i.proximaKm != null || i.proximaData != null)) ...[
        TituloSecao('Próximas revisões',
            subtitulo: p.kmPorMes == null ? null : 'Seu uso: cerca de ${formatarKm(p.kmPorMes!.round())} km por mês'),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 4),
            child: LinhaDoTempo(
              kmAtual: v.kmAtual,
              kmPorMes: p.kmPorMes,
              vencimentos: [
                for (final i in p.itens)
                  if (i.proximaKm != null || i.proximaData != null)
                    Vencimento(i.nome, km: i.proximaKm, data: i.proximaData),
              ],
            ),
          ),
        ),
      ],
      const TituloSecao('Itens de manutenção'),
      for (final item in p.itens)
        AnimatedContainer(
          key: _chaves.putIfAbsent(item.id, GlobalKey.new),
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.id == _destaque ? Theme.of(context).colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Card(
            margin: EdgeInsets.zero,
            color: item.id == _destaque ? Theme.of(context).colorScheme.primaryContainer : null,
            child: ListTile(
              leading: Icon(item.situacao.icone, color: item.situacao.cor(Theme.of(context).colorScheme)),
              title: Text(item.nome),
              subtitle: Text(_resumo(item)),
              trailing: SeloSituacao(item.situacao),
              onTap: () => _abrirItem(v.id, item),
            ),
          ),
        ),
    ]);
  }

  Widget _recado(Painel p) {
    final cores = Theme.of(context).colorScheme;
    if (p.vencidos > 0) {
      return RecadoMascote(
        cor: Situacao.vencido.cor(cores),
        titulo: p.vencidos == 1 ? '1 item vencido!' : '${p.vencidos} itens vencidos!',
        texto: 'Não deixe para depois: manutenção atrasada sai mais cara e compromete a segurança.',
      );
    }
    if (p.proximos > 0) {
      return RecadoMascote(
        cor: Situacao.proximo.cor(cores),
        titulo: p.proximos == 1 ? '1 item chegando no prazo' : '${p.proximos} itens chegando no prazo',
        texto: 'Já vale ir agendando com a sua oficina.',
      );
    }
    if (p.semRegistro == 0) {
      return RecadoMascote(
        cor: Situacao.emDia.cor(cores),
        titulo: 'Tudo em dia!',
        texto: 'Seu veículo está com as manutenções em ordem. Continue registrando o km.',
      );
    }
    return RecadoMascote(
      titulo: 'Me conte o histórico',
      texto: 'Toque nos itens "sem registro" e informe quando foram feitos pela última vez.',
    );
  }

  /// Próximo vencimento entre todos os itens com histórico: menor km e data mais cedo.
  static String? _proximaRevisao(Painel p) {
    // só o que ainda vai vencer (os atrasados aparecem no contador e na linha do tempo)
    final kms = p.itens
        .where((i) => (i.kmRestante ?? 1) > 0)
        .map((i) => i.proximaKm)
        .whereType<int>()
        .toList()
      ..sort();
    final datas = p.itens
        .where((i) => (i.diasRestantes ?? 1) > 0)
        .map((i) => i.proximaData)
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (kms.isEmpty && datas.isEmpty) return null;
    return [
      if (kms.isNotEmpty) 'aos ${formatarKm(kms.first)} km',
      if (datas.isNotEmpty) 'em ${formatarData(datas.first)}',
    ].join(' ou ');
  }

  static String _resumo(ItemManutencao i) {
    final ref = switch (i.referencia) {
      Referencia.km => 'Por km',
      Referencia.data => 'Por data',
      Referencia.ambos => '',
    };
    String juntar(List<String> partes, String sep) =>
        [if (ref.isNotEmpty) ref, partes.join(sep)].where((t) => t.isNotEmpty).join(' · ');

    if (i.situacao == Situacao.semRegistro) {
      return juntar([
        if (i.referencia.usaKm && i.intervaloKm != null) 'a cada ${formatarKm(i.intervaloKm!)} km',
        if (i.referencia.usaData && i.intervaloMeses != null) 'a cada ${i.intervaloMeses} meses',
      ], ' ou ');
    }
    return juntar([
      if (i.kmRestante != null)
        i.kmRestante! <= 0 ? 'passou ${formatarKm(-i.kmRestante!)} km' : 'faltam ${formatarKm(i.kmRestante!)} km',
      if (i.diasRestantes != null)
        i.diasRestantes! <= 0 ? 'venceu em ${formatarData(i.proximaData!)}' : 'até ${formatarData(i.proximaData!)}',
    ], ' · ');
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.rotulo, required this.valor, required this.situacao});

  final String rotulo;
  final int valor;
  final Situacao situacao;

  @override
  Widget build(BuildContext context) {
    final cor = situacao.cor(Theme.of(context).colorScheme);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: valor > 0 ? 0.12 : 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text('$valor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cor)),
          Text(rotulo, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

class _DialogoKm extends StatefulWidget {
  const _DialogoKm({required this.kmAtual});

  final int kmAtual;

  @override
  State<_DialogoKm> createState() => _DialogoKmState();
}

class _DialogoKmState extends State<_DialogoKm> {
  final _ctrl = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ok() {
    final km = int.tryParse(_ctrl.text);
    if (km == null) return setState(() => _erro = 'Informe o km');
    if (km < widget.kmAtual) {
      return setState(() => _erro = 'Menor que o último registro (${formatarKm(widget.kmAtual)} km)');
    }
    Navigator.of(context).pop(km);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Km atual'),
        content: TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          decoration: InputDecoration(
            labelText: 'Hodômetro',
            suffixText: 'km',
            helperText: 'Último: ${formatarKm(widget.kmAtual)} km',
            errorText: _erro,
          ),
          onSubmitted: (_) => _ok(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: _ok, child: const Text('Salvar')),
        ],
      );
}
