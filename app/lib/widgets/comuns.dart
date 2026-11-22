import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/cep_service.dart';
import '../api/modelos.dart';

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

/// Seletor de data em um campo somente leitura.
class CampoData extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: valor ?? hoje,
          firstDate: DateTime(1990),
          lastDate: hoje,
        );
        if (d != null) aoMudar(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          errorText: erro,
          suffixIcon: permitirLimpar && valor != null
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () => aoMudar(null))
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(valor == null
            ? ''
            : '${valor!.day.toString().padLeft(2, '0')}/${valor!.month.toString().padLeft(2, '0')}/${valor!.year}'),
      ),
    );
  }
}

/// Logo do Tok Mecânico; usa a versão branca no tema escuro.
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
