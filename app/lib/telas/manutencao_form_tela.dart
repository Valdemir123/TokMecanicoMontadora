import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import '../widgets/comuns.dart';

/// Revisão periódica: data, km e itens revisados. Mostra na hora a previsão da próxima vez de
/// cada item (km e data, conforme a referência do item). Retorna `true` via Navigator.pop quando salvo.
class ManutencaoFormTela extends StatefulWidget {
  const ManutencaoFormTela({super.key, required this.veiculo, required this.itens});

  final Veiculo veiculo;
  final List<ItemManutencao> itens;

  @override
  State<ManutencaoFormTela> createState() => _ManutencaoFormTelaState();
}

class _ManutencaoFormTelaState extends State<ManutencaoFormTela> {
  final _form = GlobalKey<FormState>();
  late final _km = TextEditingController(text: '${widget.veiculo.kmAtual}');
  final _descricao = TextEditingController();
  final _valor = TextEditingController();
  final _oficina = TextEditingController();
  DateTime _data = DateTime.now();
  final _selecionados = <String>{};
  bool _salvando = false;
  ApiException? _erro;

  @override
  void dispose() {
    for (final c in [_km, _descricao, _valor, _oficina]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _kmInformado => int.tryParse(_km.text);

  List<Previsao> _previsoes() => [
        for (final i in widget.itens)
          if (_selecionados.contains(i.id)) Previsao.de(i, _kmInformado, _data),
      ]..sort((a, b) => a.item.nome.compareTo(b.item.nome));

  /// A mais próxima entre os itens marcados: menor km e data mais cedo.
  String? _proximaRevisao() {
    final ps = _previsoes();
    final kms = ps.map((p) => p.km).whereType<int>().toList()..sort();
    final datas = ps.map((p) => p.data).whereType<DateTime>().toList()..sort();
    if (kms.isEmpty && datas.isEmpty) return null;
    final quando = [
      if (kms.isNotEmpty) 'aos ${formatarKm(kms.first)} km',
      if (datas.isNotEmpty) 'em ${formatarData(datas.first)}',
    ].join(' ou ');
    return '$quando (o que vier primeiro)';
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_form.currentState!.validate()) return;
    if (_selecionados.isEmpty && _descricao.text.trim().isEmpty) {
      mostrarMensagem(context, 'Marque ao menos um item ou descreva o serviço.', erro: true);
      return;
    }

    setState(() => _salvando = true);
    try {
      await Servicos.of(context).api.registrarManutencao(widget.veiculo.id, {
        'data': dataIso(_data),
        'km': int.parse(_km.text),
        'itensIds': _selecionados.toList(),
        'descricao': _descricao.text.trim(),
        'valor': lerValor(_valor.text),
        'oficina': _oficina.text.trim(),
      });
      if (!mounted) return;
      final previsoes = _previsoes();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.event_available, size: 36),
          title: const Text('Revisão registrada'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (previsoes.isNotEmpty) ...[
                const Text('Próximas revisões previstas:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final p in previsoes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${p.item.nome}: ${p.texto}'),
                  ),
              ] else
                const Text('Manutenção registrada no histórico.'),
            ]),
          ),
          actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Revisão periódica')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Conteudo(
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              LinhaResponsiva(children: [
                CampoData(
                  rotulo: 'Data da revisão',
                  valor: _data,
                  erro: _erro?.erroDe('data'),
                  aoMudar: (d) => setState(() => _data = d ?? DateTime.now()),
                ),
                TextFormField(
                  controller: _km,
                  decoration: InputDecoration(labelText: 'Km da revisão', suffixText: 'km', errorText: _erro?.erroDe('km')),
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                  validator: (v) => (v ?? '').isEmpty ? 'Informe o km' : null,
                ),
              ]),
              const TituloSecao('Itens revisados'),
              Row(children: [
                Expanded(
                  child: Text(_selecionados.isEmpty ? 'Marque o que foi feito' : '${_selecionados.length} selecionado(s)',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _selecionados.length == widget.itens.length
                      ? _selecionados.clear()
                      : _selecionados.addAll(widget.itens.map((i) => i.id))),
                  icon: Icon(_selecionados.length == widget.itens.length ? Icons.deselect : Icons.select_all),
                  label: Text(_selecionados.length == widget.itens.length ? 'Desmarcar todos' : 'Marcar todos'),
                ),
              ]),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  for (final item in [...widget.itens]..sort((a, b) => a.nome.compareTo(b.nome)))
                    CheckboxListTile(
                      value: _selecionados.contains(item.id),
                      onChanged: (marcado) => setState(() =>
                          marcado == true ? _selecionados.add(item.id) : _selecionados.remove(item.id)),
                      title: Text(item.nome),
                      subtitle: _selecionados.contains(item.id)
                          ? Text('Próxima: ${Previsao.de(item, _kmInformado, _data).texto}',
                              style: TextStyle(color: Theme.of(context).colorScheme.primary))
                          : null,
                      secondary: _selecionados.contains(item.id) ? null : SeloSituacao(item.situacao),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ]),
              ),
              if (_proximaRevisao() case final resumo?) ...[
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.event_repeat),
                    title: const Text('Próxima revisão prevista', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(resumo),
                  ),
                ),
              ],
              if (_erro?.erroDe('itensIds') case final msg?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const TituloSecao('Detalhes (opcional)'),
              TextFormField(
                controller: _descricao,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex.: Óleo 5W30 sintético, peças trocadas…',
                ),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 12),
              LinhaResponsiva(children: [
                TextFormField(
                  controller: _valor,
                  decoration: InputDecoration(labelText: 'Valor total', prefixText: 'R\$ ', errorText: _erro?.erroDe('valor')),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                ),
                TextFormField(
                  controller: _oficina,
                  decoration: const InputDecoration(labelText: 'Oficina / loja'),
                  textCapitalization: TextCapitalization.words,
                ),
              ]),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Salvar revisão'),
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

/// Previsão da próxima vez de um item, a partir do km e da data da revisão.
class Previsao {
  Previsao(this.item, this.km, this.data);

  final ItemManutencao item;
  final int? km;
  final DateTime? data;

  factory Previsao.de(ItemManutencao i, int? kmRevisao, DateTime dataRevisao) => Previsao(
        i,
        i.referencia.usaKm && i.intervaloKm != null && kmRevisao != null ? kmRevisao + i.intervaloKm! : null,
        i.referencia.usaData && i.intervaloMeses != null ? somarMeses(dataRevisao, i.intervaloMeses!) : null,
      );

  String get texto {
    final partes = [
      if (km != null) '${formatarKm(km!)} km',
      if (data != null) formatarData(data!),
    ];
    return partes.isEmpty ? 'informe o km' : partes.join(' ou ');
  }
}
