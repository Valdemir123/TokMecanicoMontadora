import 'package:app/widgets/linha_do_tempo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _tela(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

void main() {
  final hoje = DateTime(2026, 11, 23);

  testWidgets('agrupa por mês/ano, separa atrasadas e itens só por km', (tester) async {
    await tester.pumpWidget(_tela(LinhaDoTempo(
      hoje: hoje,
      kmAtual: 17000,
      vencimentos: [
        Vencimento('Troca de óleo', km: 25000, data: DateTime(2027, 3, 10)),
        Vencimento('Filtro de ar', data: DateTime(2027, 3, 28)),
        Vencimento('Bateria', data: DateTime(2029, 1, 10)),
        Vencimento('Fluido de freio', data: DateTime(2026, 10, 1)),
        Vencimento('Pastilhas', km: 47000),
      ],
    )));
    expect(find.text('ATRASADAS'), findsOneWidget);
    expect(find.text('MAR/2027'), findsOneWidget);
    expect(find.text('JAN/2029'), findsOneWidget);
    expect(find.text('PELA QUILOMETRAGEM'), findsOneWidget);
  });

  testWidgets('com ritmo de uso, item por km vai para o mês estimado', (tester) async {
    await tester.pumpWidget(_tela(LinhaDoTempo(
      hoje: hoje,
      kmAtual: 17000,
      kmPorMes: 1000, // 30.000 km faltando -> ~30 meses -> mai/2029
      vencimentos: [Vencimento('Pastilhas', km: 47000)],
    )));
    expect(find.text('PELA QUILOMETRAGEM'), findsNothing);
    expect(find.text('MAI/2029'), findsOneWidget);
    expect(find.textContaining('mês estimado pelo seu uso'), findsOneWidget);
  });
}
