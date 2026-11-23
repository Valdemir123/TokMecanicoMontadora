import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/cep_service.dart';
import '../api/modelos.dart';
import '../util/formatos.dart';

/// Disponibiliza os serviços (API e CEP) para as telas.
class Servicos extends InheritedWidget {
  const Servicos({super.key, required this.api, required this.cep, required super.child});

  final ApiClient api;
  final CepService cep;

  static Servicos of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Servicos>()!;

  @override
  bool updateShouldNotify(Servicos oldWidget) => api != oldWidget.api || cep != oldWidget.cep;
}

/// Centraliza o conteúdo com largura máxima: no celular ocupa a tela, no computador vira uma coluna legível.
class Conteudo extends StatelessWidget {
  const Conteudo({super.key, required this.child, this.larguraMaxima = 720});

  final Widget child;
  final double larguraMaxima;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        heightFactor: 1, // ocupa só a altura do conteúdo (ex.: rodapé com botão)
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: larguraMaxima),
          child: child,
        ),
      );
}

/// Duas colunas em telas largas, uma coluna no celular.
class LinhaResponsiva extends StatelessWidget {
  const LinhaResponsiva({super.key, required this.children, this.flex});

  final List<Widget> children;
  final List<int>? flex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 520) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(flex: flex?[i] ?? 1, child: children[i]),
            ],
          ],
        );
      });
}

class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.subtitulo});

  final String texto;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (subtitulo != null)
            Text(subtitulo!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Logo da montadora (ou um ícone de carro se não houver logo).
class LogoMontadora extends StatelessWidget {
  const LogoMontadora(this.asset, {super.key, this.tamanho = 40});

  final String? asset;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final icone = Icon(Icons.directions_car, size: tamanho * 0.7, color: Theme.of(context).colorScheme.primary);
    return SizedBox.square(
      dimension: tamanho,
      child: asset == null
          ? icone
          : Image.asset(asset!, fit: BoxFit.contain, errorBuilder: (_, _, _) => icone),
    );
  }
}

/// Cores e textos de cada situação de manutenção.
extension SituacaoVisual on Situacao {
  String get rotulo => switch (this) {
        Situacao.vencido => 'Vencido',
        Situacao.proximo => 'Próximo',
        Situacao.emDia => 'Em dia',
        Situacao.semRegistro => 'Sem registro',
      };

  Color cor(ColorScheme c) => switch (this) {
        Situacao.vencido => c.error,
        Situacao.proximo => const Color(0xFFE08A00),
        Situacao.emDia => const Color(0xFF2E7D32),
        Situacao.semRegistro => c.outline,
      };

  IconData get icone => switch (this) {
        Situacao.vencido => Icons.error,
        Situacao.proximo => Icons.schedule,
        Situacao.emDia => Icons.check_circle,
        Situacao.semRegistro => Icons.help_outline,
      };
}

class SeloSituacao extends StatelessWidget {
  const SeloSituacao(this.situacao, {super.key});

  final Situacao situacao;

  @override
  Widget build(BuildContext context) {
    final cor = situacao.cor(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(situacao.icone, size: 14, color: cor),
        const SizedBox(width: 4),
        Text(situacao.rotulo, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Tela de erro com botão de tentar de novo.
class ErroCarregar extends StatelessWidget {
  const ErroCarregar({super.key, required this.erro, required this.tentarDeNovo});

  final Object erro;
  final VoidCallback tentarDeNovo;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('$erro', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: tentarDeNovo, child: const Text('Tentar de novo')),
          ]),
        ),
      );
}

void mostrarMensagem(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(texto),
    backgroundColor: erro ? Theme.of(context).colorScheme.error : null,
  ));
}

/// Campo de data: digitação direta (dd/mm/aaaa) ou escolha no calendário pelo botão.
class CampoData extends StatefulWidget {
  const CampoData({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.aoMudar,
    this.erro,
    this.permitirLimpar = false,
  });

  final String rotulo;
  final DateTime? valor;
  final ValueChanged<DateTime?> aoMudar;
  final String? erro;
  final bool permitirLimpar;

  @override
  State<CampoData> createState() => _CampoDataState();
}

class _CampoDataState extends State<CampoData> {
  final _ctrl = TextEditingController();
  String? _erroLocal;

  @override
  void initState() {
    super.initState();
    _ctrl.text = _texto(widget.valor);
  }

  @override
  void didUpdateWidget(CampoData old) {
    super.didUpdateWidget(old);
    // valor mudado por fora (ex.: calendário ou limpar)
    if (widget.valor != old.valor && _ler(_ctrl.text) != widget.valor) _ctrl.text = _texto(widget.valor);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static String _texto(DateTime? d) => d == null ? '' : formatarData(d);

  static DateTime? _ler(String t) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(t);
    if (m == null) return null;
    final d = DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    // rejeita datas como 31/02 (que o DateTime "corrige" para março)
    return d.day == int.parse(m[1]!) && d.month == int.parse(m[2]!) ? d : null;
  }

  void _digitou(String t) {
    final hoje = DateTime.now();
    if (t.isEmpty) {
      setState(() => _erroLocal = null);
      widget.aoMudar(null);
      return;
    }
    if (t.length < 10) {
      setState(() => _erroLocal = null);
      return;
    }
    final d = _ler(t);
    String? erro;
    if (d == null) {
      erro = 'Data inválida';
    } else if (d.isAfter(hoje)) {
      erro = 'Não pode ser no futuro';
    } else if (d.year < 1950) {
      erro = 'Data muito antiga';
    }
    setState(() => _erroLocal = erro);
    if (erro == null) widget.aoMudar(d);
  }

  Future<void> _calendario() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: widget.valor ?? hoje,
      firstDate: DateTime(1950),
      lastDate: hoje,
    );
    if (d == null) return;
    _ctrl.text = _texto(d);
    setState(() => _erroLocal = null);
    widget.aoMudar(d);
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: _ctrl,
        keyboardType: TextInputType.datetime,
        inputFormatters: [MascaraDigitos('##/##/####')],
        decoration: InputDecoration(
          labelText: widget.rotulo,
          hintText: 'dd/mm/aaaa',
          errorText: _erroLocal ?? widget.erro,
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.permitirLimpar && widget.valor != null)
              IconButton(
                tooltip: 'Limpar',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _ctrl.clear();
                  widget.aoMudar(null);
                },
              ),
            IconButton(tooltip: 'Abrir calendário', icon: const Icon(Icons.calendar_today, size: 18), onPressed: _calendario),
          ]),
        ),
        onChanged: _digitou,
      );
}

/// Logo do Tok Mecânico (checklist + carro + nome); usa a versão branca no tema escuro.
class LogoTok extends StatelessWidget {
  const LogoTok({super.key, this.altura = 140, this.soSimbolo = false});

  final double altura;

  /// Só o desenho (checklist + carro), sem o nome.
  final bool soSimbolo;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final nome = soSimbolo ? 'simbolo' : 'logo-vertical';
    return Image.asset(
      'assets/logo/$nome${escuro ? '-branco' : ''}.png',
      height: altura,
      fit: BoxFit.contain,
      semanticLabel: 'Tok Mecânico',
    );
  }
}

/// Mascote do Tok Mecânico: caricatura do fundador como mecânico, com chave inglesa.
class Mascote extends StatelessWidget {
  const Mascote({super.key, this.altura = 140});

  final double altura;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/mascote/mecanico.png',
        height: altura,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
}

/// Recado do mascote: o mecânico ao lado de um balão de texto.
class RecadoMascote extends StatelessWidget {
  const RecadoMascote({super.key, required this.titulo, required this.texto, this.cor, this.acao});

  final String titulo;
  final String texto;
  final Color? cor;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final destaque = cor ?? Theme.of(context).colorScheme.primary;
    return Card(
      color: destaque.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: destaque.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
        child: Row(children: [
          const Mascote(altura: 96),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: destaque)),
              const SizedBox(height: 4),
              Text(texto),
              if (acao != null) ...[const SizedBox(height: 8), acao!],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Tela "Sobre o Tok Mecânico".
void mostrarSobre(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'Tok Mecânico',
    applicationVersion: '1.0.0',
    applicationIcon: const LogoTok(altura: 48, soSimbolo: true),
    applicationLegalese: 'Controle de manutenções do seu veículo.',
    children: const [
      SizedBox(height: 16),
      Center(child: Mascote(altura: 120)),
    ],
  );
}

/// Campo de senha com botão de mostrar/ocultar.
class CampoSenha extends StatefulWidget {
  const CampoSenha({super.key, required this.controller, required this.rotulo, this.validator, this.erroApi, this.aoEnviar});

  final TextEditingController controller;
  final String rotulo;
  final FormFieldValidator<String>? validator;
  final String? erroApi;
  final VoidCallback? aoEnviar;

  @override
  State<CampoSenha> createState() => _CampoSenhaState();
}

class _CampoSenhaState extends State<CampoSenha> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _oculta,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: widget.rotulo,
          errorText: widget.erroApi,
          suffixIcon: IconButton(
            tooltip: _oculta ? 'Mostrar senha' : 'Ocultar senha',
            icon: Icon(_oculta ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _oculta = !_oculta),
          ),
        ),
        validator: widget.validator,
        onFieldSubmitted: widget.aoEnviar == null ? null : (_) => widget.aoEnviar!(),
      );
}

/// Resumo dos termos de uso e da política de privacidade.
/// TEXTO PROVISÓRIO: precisa ser revisado por um advogado antes da publicação.
void mostrarTermos(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Termos de uso e privacidade'),
      content: const SingleChildScrollView(
        child: Text(
          'Versão provisória.\n\n'
          'Quais dados coletamos: CPF, nome, e-mail e celular (opcionais), endereços residencial e de '
          'trabalho, dados dos seus veículos, quilometragem e manutenções que você registrar.\n\n'
          'Para que usamos: identificar sua conta, calcular e avisar sobre as manutenções do seu veículo e, '
          'no futuro, sugerir oficinas e lojas próximas aos seus endereços.\n\n'
          'Com quem compartilhamos: não vendemos seus dados. Lojas e oficinas parceiras só recebem '
          'informações com a sua autorização.\n\n'
          'Seus direitos (LGPD): você pode consultar, corrigir e pedir a exclusão dos seus dados a qualquer '
          'momento pelo próprio app ou pelo nosso contato.\n\n'
          'Segurança: sua senha é guardada de forma criptografada e o acesso aos seus dados exige login.',
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar'))],
    ),
  );
}
