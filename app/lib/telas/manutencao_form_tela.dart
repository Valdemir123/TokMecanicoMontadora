import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import '../widgets/comuns.dart';

/// Registra uma manutenção realizada, marcando os itens atendidos.
/// Retorna `true` via Navigator.pop quando salvo.
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
      mostrarMensagem(context, 'Manutenção registrada.');
      Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('Registrar manutenção')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Conteudo(
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              LinhaResponsiva(children: [
                CampoData(
                  rotulo: 'Data',
                  valor: _data,
                  erro: _erro?.erroDe('data'),
                  aoMudar: (d) => setState(() => _data = d ?? DateTime.now()),
                ),
                TextFormField(
                  controller: _km,
                  decoration: InputDecoration(labelText: 'Km no dia', suffixText: 'km', errorText: _erro?.erroDe('km')),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                  validator: (v) => (v ?? '').isEmpty ? 'Informe o km' : null,
                ),
              ]),
              TituloSecao('O que foi feito?',
                  subtitulo: _selecionados.isEmpty ? null : '${_selecionados.length} selecionado(s)'),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  for (final item in widget.itens)
                    CheckboxListTile(
                      value: _selecionados.contains(item.id),
                      onChanged: (marcado) => setState(() =>
                          marcado == true ? _selecionados.add(item.id) : _selecionados.remove(item.id)),
                      title: Text(item.nome),
                      secondary: SeloSituacao(item.situacao),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ]),
              ),
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
                label: const Text('Salvar manutenção'),
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
