import 'package:material_ui/material_ui.dart';

import '../util/formatos.dart';

/// Um vencimento previsto: por km, por data ou os dois (vale o que vier primeiro).
class Vencimento {
  Vencimento(this.nome, {this.km, this.data});

  final String nome;
  final int? km;
  final DateTime? data;
}

const _meses = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];

class _Previsto {
  _Previsto(this.v, this.quando, this.estimado);

  final Vencimento v;
  final DateTime? quando; // data efetiva (a mais cedo entre a data e a estimativa pelo km)
  final bool estimado; // a data veio da estimativa pelo km/mês
}

/// Próximas revisões agrupadas por mês/ano. Itens por km entram no mês estimado pelo
/// ritmo de uso ([kmPorMes]); sem estimativa, ficam no bloco "Pela quilometragem".
class LinhaDoTempo extends StatelessWidget {
  const LinhaDoTempo({super.key, required this.vencimentos, required this.kmAtual, this.kmPorMes, this.hoje});

  final List<Vencimento> vencimentos;
  final int kmAtual;
  final double? kmPorMes;
  final DateTime? hoje;

  List<_Previsto> _prever(DateTime hoje) => [
        for (final v in vencimentos)
          if (v.km != null || v.data != null) _prever1(v, hoje),
      ];

  _Previsto _prever1(Vencimento v, DateTime hoje) {
    DateTime? pelaKm;
    if (v.km != null && kmPorMes != null && kmPorMes! > 0) {
      final faltam = v.km! - kmAtual;
      pelaKm = faltam <= 0 ? hoje : hoje.add(Duration(days: (faltam / kmPorMes! * 30.44).round()));
    }
    if (v.data == null) return _Previsto(v, pelaKm, pelaKm != null);
    if (pelaKm != null && pelaKm.isBefore(v.data!)) return _Previsto(v, pelaKm, true);
    return _Previsto(v, v.data, false);
  }

  @override
  Widget build(BuildContext context) {
    final agora = hoje ?? DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month);
    final previstos = _prever(agora);
    if (previstos.isEmpty) return const SizedBox.shrink();

    final atrasados = <_Previsto>[];
    final porMes = <DateTime, List<_Previsto>>{};
    final soKm = <_Previsto>[];
    for (final p in previstos) {
      final q = p.quando;
      if (q == null) {
        soKm.add(p);
      } else if (q.isBefore(inicioMes) || (p.v.km != null && p.v.km! <= kmAtual)) {
        atrasados.add(p);
      } else {
        porMes.putIfAbsent(DateTime(q.year, q.month), () => []).add(p);
      }
    }
    final meses = porMes.keys.toList()..sort();
    soKm.sort((a, b) => a.v.km!.compareTo(b.v.km!));
    final cores = Theme.of(context).colorScheme;

    final grupos = <(String, Color, List<_Previsto>)>[
      if (atrasados.isNotEmpty) ('ATRASADAS', cores.error, atrasados),
      for (final m in meses)
        ('${_meses[m.month - 1]}/${m.year}', m == inicioMes ? const Color(0xFFE08A00) : cores.primary, porMes[m]!),
      if (soKm.isNotEmpty) ('PELA QUILOMETRAGEM', cores.outline, soKm),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var g = 0; g < grupos.length; g++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // trilho da linha do tempo
            SizedBox(
              width: 28,
              child: Column(children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(color: grupos[g].$2, shape: BoxShape.circle),
                ),
                if (g < grupos.length - 1)
                  Expanded(child: Container(width: 2, color: cores.outlineVariant)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(grupos[g].$1,
                      style: TextStyle(fontWeight: FontWeight.bold, color: grupos[g].$2, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  for (final p in grupos[g].$3..sort((a, b) => a.v.nome.compareTo(b.v.nome)))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('•  '),
                        Expanded(
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: p.v.nome),
                            TextSpan(
                              text: '  ${_detalhe(p)}',
                              style: TextStyle(fontSize: 12, color: cores.onSurfaceVariant),
                            ),
                          ])),
                        ),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      if (soKm.isNotEmpty && (kmPorMes == null || kmPorMes! <= 0))
        Text(
          'Itens por km aparecerão no mês previsto quando houver histórico de km suficiente '
          '(registre o km de vez em quando).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ]);
  }

  static String _detalhe(_Previsto p) {
    final partes = [
      if (p.v.km != null) 'aos ${formatarKm(p.v.km!)} km',
      if (p.v.data != null) 'até ${formatarData(p.v.data!)}',
      if (p.estimado) 'mês estimado pelo seu uso',
    ];
    return partes.join(' · ');
  }
}
