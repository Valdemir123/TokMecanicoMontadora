import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';
import 'comuns.dart';

/// Controladores de um endereço; preencher o CEP busca o resto automaticamente.
class EnderecoControles {
  final cep = TextEditingController();
  final logradouro = TextEditingController();
  final numero = TextEditingController();
  final complemento = TextEditingController();
  final bairro = TextEditingController();
  final cidade = TextEditingController();
  final uf = TextEditingController();

  List<TextEditingController> get _todos => [cep, logradouro, numero, complemento, bairro, cidade, uf];

  bool get vazio => _todos.every((c) => c.text.trim().isEmpty);

  void preencher(Endereco? e) {
    if (e == null) return;
    cep.text = mascaraCep.aplicar(e.cep);
    logradouro.text = e.logradouro;
    numero.text = e.numero;
    complemento.text = e.complemento ?? '';
    bairro.text = e.bairro;
    cidade.text = e.cidade;
    uf.text = e.uf;
  }

  Map<String, dynamic> toJson() => {
        'cep': somenteDigitos(cep.text),
        'logradouro': logradouro.text.trim(),
        'numero': numero.text.trim(),
        'complemento': complemento.text.trim(),
        'bairro': bairro.text.trim(),
        'cidade': cidade.text.trim(),
        'uf': uf.text.trim().toUpperCase(),
      };

  void dispose() {
    for (final c in _todos) {
      c.dispose();
    }
  }
}

class EnderecoForm extends StatefulWidget {
  const EnderecoForm({
    super.key,
    required this.controles,
    required this.prefixoErro,
    this.erroApi,
    this.obrigatorio = true,
  });

  final EnderecoControles controles;

  /// Prefixo dos erros da API ("enderecoResidencial" ou "enderecoTrabalho").
  final String prefixoErro;
  final ApiException? erroApi;

  /// Se falso, o endereço pode ficar todo em branco.
  final bool obrigatorio;

  @override
  State<EnderecoForm> createState() => _EnderecoFormState();
}

class _EnderecoFormState extends State<EnderecoForm> {
  bool _buscando = false;
  String? _avisoCep;
  String _ultimoCepBuscado = '';
  final _numeroFoco = FocusNode();

  EnderecoControles get c => widget.controles;

  @override
  void dispose() {
    _numeroFoco.dispose();
    super.dispose();
  }

  Future<void> _buscarCep(String valor) async {
    final digitos = somenteDigitos(valor);
    if (digitos.length != 8 || digitos == _ultimoCepBuscado) return;
    _ultimoCepBuscado = digitos;
    setState(() {
      _buscando = true;
      _avisoCep = null;
    });
    final r = await Servicos.of(context).cep.buscar(digitos);
    if (!mounted) return;
    setState(() {
      _buscando = false;
      if (r == null) {
        _avisoCep = 'CEP não encontrado. Preencha o endereço manualmente.';
      } else {
        if (r.logradouro.isNotEmpty) c.logradouro.text = r.logradouro;
        if (r.bairro.isNotEmpty) c.bairro.text = r.bairro;
        c.cidade.text = r.cidade;
        c.uf.text = r.uf;
      }
    });
    if (r != null) _numeroFoco.requestFocus();
  }

  /// Validação só se aplica quando o endereço é obrigatório ou já começou a ser preenchido.
  String? Function(String?) _req(String msg) =>
      (v) => (widget.obrigatorio || !c.vazio) && (v == null || v.trim().isEmpty) ? msg : null;

  String? _api(String campo) => widget.erroApi?.erroDe('${widget.prefixoErro}.$campo');

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      LinhaResponsiva(flex: const [2, 3], children: [
        TextFormField(
          controller: c.cep,
          decoration: InputDecoration(
            labelText: 'CEP',
            hintText: '00000-000',
            errorText: _api('cep'),
            helperText: _avisoCep,
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.search),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [mascaraCep],
          onChanged: _buscarCep,
          validator: (v) {
            if (!widget.obrigatorio && c.vazio) return null;
            return somenteDigitos(v ?? '').length == 8 ? null : 'CEP inválido';
          },
        ),
        const SizedBox.shrink(),
      ]),
      const SizedBox(height: 12),
      LinhaResponsiva(flex: const [4, 1], children: [
        TextFormField(
          controller: c.logradouro,
          decoration: InputDecoration(labelText: 'Logradouro', errorText: _api('logradouro')),
          textCapitalization: TextCapitalization.words,
          validator: _req('Informe o logradouro'),
        ),
        TextFormField(
          controller: c.numero,
          focusNode: _numeroFoco,
          decoration: InputDecoration(labelText: 'Número', hintText: 'S/N', errorText: _api('numero')),
          validator: _req('Informe o número'),
        ),
      ]),
      const SizedBox(height: 12),
      LinhaResponsiva(children: [
        TextFormField(
          controller: c.complemento,
          decoration: const InputDecoration(labelText: 'Complemento (opcional)'),
        ),
        TextFormField(
          controller: c.bairro,
          decoration: InputDecoration(labelText: 'Bairro', errorText: _api('bairro')),
          textCapitalization: TextCapitalization.words,
          validator: _req('Informe o bairro'),
        ),
      ]),
      const SizedBox(height: 12),
      LinhaResponsiva(flex: const [4, 1], children: [
        TextFormField(
          controller: c.cidade,
          decoration: InputDecoration(labelText: 'Cidade', errorText: _api('cidade')),
          textCapitalization: TextCapitalization.words,
          validator: _req('Informe a cidade'),
        ),
        TextFormField(
          controller: c.uf,
          decoration: InputDecoration(labelText: 'UF', errorText: _api('uf')),
          textCapitalization: TextCapitalization.characters,
          maxLength: 2,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          validator: (v) {
            if (!widget.obrigatorio && c.vazio) return null;
            return RegExp(r'^[A-Za-z]{2}$').hasMatch((v ?? '').trim()) ? null : 'UF';
          },
        ),
      ]),
    ]);
  }
}
