import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import '../widgets/comuns.dart';

/// Cria um item pessoal ou ajusta um item existente (intervalos e última realização).
/// Retorna `true` via Navigator.pop quando algo foi salvo.
class ItemFormTela extends StatefulWidget {
  const ItemFormTela({super.key, required this.veiculoId, this.item});

  final String veiculoId;
  final ItemManutencao? item;

  @override
  State<ItemFormTela> createState() => _ItemFormTelaState();
}

class _ItemFormTelaState extends State<ItemFormTela> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _obs = TextEditingController();
  final _intervaloKm = TextEditingController();
  final _intervaloMeses = TextEditingController();
  final _ultimaKm = TextEditingController();
  DateTime? _ultimaData;
  bool _salvando = false;
  ApiException? _erro;

  bool get _editando => widget.item != null;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    if (i != null) {
      _nome.text = i.nome;
      _obs.text = i.observacao ?? '';
      _intervaloKm.text = i.intervaloKm?.toString() ?? '';
      _intervaloMeses.text = i.intervaloMeses?.toString() ?? '';
      _ultimaKm.text = i.ultimaKm?.toString() ?? '';
      _ultimaData = i.ultimaData;
    }
  }

  @override
  void dispose() {
    for (final c in [_nome, _obs, _intervaloKm, _intervaloMeses, _ultimaKm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_form.currentState!.validate()) return;

    final dados = {
      'nome': _nome.text.trim(),
      'observacao': _obs.text.trim(),
      'intervaloKm': int.tryParse(_intervaloKm.text),
      'intervaloMeses': int.tryParse(_intervaloMeses.text),
      'ultimaKm': int.tryParse(_ultimaKm.text),
      'ultimaData': _ultimaData == null ? null : dataIso(_ultimaData!),
    };

    setState(() => _salvando = true);
    final api = Servicos.of(context).api;
    try {
      if (_editando) {
        await api.atualizarItem(widget.veiculoId, widget.item!.id, dados);
      } else {
        await api.criarItem(widget.veiculoId, dados);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e);
      mostrarMensagem(context, e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover item?'),
        content: Text('"${widget.item!.nome}" deixará de ser acompanhado neste veículo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Servicos.of(context).api.excluirItem(widget.veiculoId, widget.item!.id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem, erro: true);
    }
  }

  String? _semIntervalo() =>
      _intervaloKm.text.isEmpty && _intervaloMeses.text.isEmpty ? 'Informe km, meses ou ambos' : null;

  @override
  Widget build(BuildContext context) {
    final numeros = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)];
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? item!.nome : 'Novo item pessoal'),
        actions: [
          if (_editando)
            IconButton(tooltip: 'Remover item', icon: const Icon(Icons.delete_outline), onPressed: _excluir),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Conteudo(
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (item != null && item.situacao != Situacao.semRegistro) ...[
                Row(children: [SeloSituacao(item.situacao)]),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _nome,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex.: Lavagem, Higienização do ar, Seguro',
                  errorText: _erro?.erroDe('nome'),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _obs,
                decoration: const InputDecoration(labelText: 'Observação (opcional)'),
              ),
              const TituloSecao('Repetir a cada', subtitulo: 'O que acontecer primeiro.'),
              LinhaResponsiva(children: [
                TextFormField(
                  controller: _intervaloKm,
                  decoration: InputDecoration(labelText: 'Km', suffixText: 'km', errorText: _erro?.erroDe('intervaloKm')),
                  keyboardType: TextInputType.number,
                  inputFormatters: numeros,
                  validator: (_) => _semIntervalo(),
                ),
                TextFormField(
                  controller: _intervaloMeses,
                  decoration: InputDecoration(
                    labelText: 'Meses',
                    suffixText: 'meses',
                    errorText: _erro?.erroDe('intervaloMeses'),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                  validator: (_) => _semIntervalo(),
                ),
              ]),
              const TituloSecao('Última vez que foi feito',
                  subtitulo: 'Se não souber, deixe em branco. Ao registrar uma manutenção, isso é atualizado.'),
              LinhaResponsiva(children: [
                TextFormField(
                  controller: _ultimaKm,
                  decoration: InputDecoration(labelText: 'Km', suffixText: 'km', errorText: _erro?.erroDe('ultimaKm')),
                  keyboardType: TextInputType.number,
                  inputFormatters: numeros,
                ),
                CampoData(
                  rotulo: 'Data',
                  valor: _ultimaData,
                  erro: _erro?.erroDe('ultimaData'),
                  permitirLimpar: true,
                  aoMudar: (d) => setState(() => _ultimaData = d),
                ),
              ]),
              if (item?.proximaKm != null || item?.proximaData != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Próxima: ${[
                    if (item!.proximaKm != null) '${formatarKm(item.proximaKm!)} km',
                    if (item.proximaData != null) formatarData(item.proximaData!),
                  ].join(' ou ')}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Salvar'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
