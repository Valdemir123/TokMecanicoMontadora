import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import '../widgets/comuns.dart';

/// Cadastro ou edição de veículo. Retorna o [Veiculo] salvo via Navigator.pop.
class VeiculoFormTela extends StatefulWidget {
  const VeiculoFormTela({super.key, this.veiculo});

  final Veiculo? veiculo;

  @override
  State<VeiculoFormTela> createState() => _VeiculoFormTelaState();
}

class _VeiculoFormTelaState extends State<VeiculoFormTela> {
  final _form = GlobalKey<FormState>();
  final _placa = TextEditingController();
  final _modelo = TextEditingController();
  final _ano = TextEditingController();
  final _cor = TextEditingController();
  final _km = TextEditingController();

  Future<List<Fabricante>>? _fabricantes;
  String? _fabricante;
  bool _salvando = false;
  ApiException? _erro;

  bool get _editando => widget.veiculo != null;

  static const _cores = ['Branco', 'Preto', 'Prata', 'Cinza', 'Vermelho', 'Azul', 'Verde', 'Marrom', 'Bege', 'Amarelo'];

  @override
  void initState() {
    super.initState();
    final v = widget.veiculo;
    if (v != null) {
      _placa.text = v.placa;
      _modelo.text = v.modelo;
      _ano.text = '${v.anoFabricacao}';
      _cor.text = v.cor;
      _fabricante = v.fabricante;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fabricantes ??= Servicos.of(context).api.fabricantes();
  }

  @override
  void dispose() {
    for (final c in [_placa, _modelo, _ano, _cor, _km]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    final fabricanteOk = _fabricante != null;
    if (!_form.currentState!.validate() || !fabricanteOk) {
      if (!fabricanteOk) mostrarMensagem(context, 'Escolha o fabricante.', erro: true);
      return;
    }

    final dados = {
      'placa': _placa.text,
      'fabricante': _fabricante,
      'modelo': _modelo.text.trim(),
      'anoFabricacao': int.parse(_ano.text),
      'cor': _cor.text.trim(),
      if (!_editando) 'kmAtual': int.tryParse(somenteDigitos(_km.text)),
    };

    setState(() => _salvando = true);
    final api = Servicos.of(context).api;
    try {
      final v = _editando
          ? await api.atualizarVeiculo(widget.veiculo!.id, dados)
          : await api.criarVeiculo(dados);
      if (mounted) Navigator.of(context).pop(v);
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
    final anoMax = DateTime.now().year + 1;
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar veículo' : 'Novo veículo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Conteudo(
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const TituloSecao('Fabricante'),
              FutureBuilder<List<Fabricante>>(
                future: _fabricantes,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return ErroCarregar(
                      erro: snap.error!,
                      tentarDeNovo: () => setState(() => _fabricantes = Servicos.of(context).api.fabricantes()),
                    );
                  }
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  return _GradeFabricantes(
                    fabricantes: snap.data!,
                    selecionado: _fabricante,
                    aoSelecionar: (f) => setState(() => _fabricante = f),
                  );
                },
              ),
              if (_erro?.erroDe('fabricante') case final msg?)
                Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const TituloSecao('Dados do veículo'),
              LinhaResponsiva(children: [
                TextFormField(
                  controller: _placa,
                  decoration: InputDecoration(labelText: 'Placa', hintText: 'ABC1D23', errorText: _erro?.erroDe('placa')),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [MascaraPlaca()],
                  validator: (v) => placaValida(v ?? '') ? null : 'Placa inválida (ABC1234 ou ABC1D23)',
                ),
                TextFormField(
                  controller: _modelo,
                  decoration: InputDecoration(labelText: 'Modelo', hintText: 'Ex.: Argo 1.0', errorText: _erro?.erroDe('modelo')),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o modelo' : null,
                ),
              ]),
              const SizedBox(height: 12),
              LinhaResponsiva(children: [
                TextFormField(
                  controller: _ano,
                  decoration: InputDecoration(labelText: 'Ano de fabricação', errorText: _erro?.erroDe('anoFabricacao')),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  validator: (v) {
                    final ano = int.tryParse(v ?? '');
                    return ano == null || ano < 1900 || ano > anoMax ? 'Ano entre 1900 e $anoMax' : null;
                  },
                ),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _cor.text),
                  optionsBuilder: (v) => _cores.where((c) => c.toLowerCase().startsWith(v.text.toLowerCase())),
                  onSelected: (c) => _cor.text = c,
                  fieldViewBuilder: (context, ctrl, foco, aoEnviar) => TextFormField(
                    controller: ctrl,
                    focusNode: foco,
                    decoration: InputDecoration(labelText: 'Cor', errorText: _erro?.erroDe('cor')),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (t) => _cor.text = t,
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Informe a cor' : null,
                  ),
                ),
              ]),
              if (!_editando) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _km,
                  decoration: InputDecoration(
                    labelText: 'Km atual (hodômetro)',
                    suffixText: 'km',
                    errorText: _erro?.erroDe('kmAtual'),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                  validator: (v) => (v ?? '').isEmpty ? 'Informe o km atual' : null,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_editando ? 'Salvar alterações' : 'Cadastrar veículo'),
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

class _GradeFabricantes extends StatelessWidget {
  const _GradeFabricantes({required this.fabricantes, required this.selecionado, required this.aoSelecionar});

  final List<Fabricante> fabricantes;
  final String? selecionado;
  final ValueChanged<String> aoSelecionar;

  Future<void> _outro(BuildContext context) async {
    final ctrl = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Outro fabricante'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome do fabricante'),
          onSubmitted: (t) => Navigator.of(ctx).pop(t),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: const Text('OK')),
        ],
      ),
    );
    ctrl.dispose();
    if (nome != null && nome.trim().isNotEmpty) aoSelecionar(nome.trim());
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final conhecido = fabricantes.any((f) => f.nome == selecionado);

    Widget opcao({required Widget icone, required String nome, required bool marcado, required VoidCallback aoTocar}) =>
        Material(
          color: marcado ? cores.primaryContainer : cores.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: marcado ? cores.primary : Colors.transparent, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: aoTocar,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Expanded(child: icone),
                const SizedBox(height: 4),
                Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        );

    return GridView.extent(
      maxCrossAxisExtent: 96,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final f in fabricantes)
          opcao(
            icone: LogoMontadora(f.assetLogo, tamanho: 48),
            nome: f.nome,
            marcado: f.nome == selecionado,
            aoTocar: () => aoSelecionar(f.nome),
          ),
        opcao(
          icone: Icon(Icons.more_horiz, size: 32, color: cores.primary),
          nome: selecionado != null && !conhecido ? selecionado! : 'Outro',
          marcado: selecionado != null && !conhecido,
          aoTocar: () => _outro(context),
        ),
      ],
    );
  }
}
