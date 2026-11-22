// Modelos espelhando os contratos JSON da API (api/Contracts/Dtos.cs).

DateTime? _data(Object? v) => v == null ? null : DateTime.parse(v as String);

/// Formata uma data como "AAAA-MM-DD" (DateOnly na API).
String dataIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Endereco {
  Endereco({
    required this.cep,
    required this.logradouro,
    required this.numero,
    this.complemento,
    required this.bairro,
    required this.cidade,
    required this.uf,
  });

  final String cep;
  final String logradouro;
  final String numero;
  final String? complemento;
  final String bairro;
  final String cidade;
  final String uf;

  factory Endereco.fromJson(Map<String, dynamic> j) => Endereco(
        cep: j['cep'],
        logradouro: j['logradouro'],
        numero: j['numero'],
        complemento: j['complemento'],
        bairro: j['bairro'],
        cidade: j['cidade'],
        uf: j['uf'],
      );

  Map<String, dynamic> toJson() => {
        'cep': cep,
        'logradouro': logradouro,
        'numero': numero,
        'complemento': complemento,
        'bairro': bairro,
        'cidade': cidade,
        'uf': uf,
      };
}

class Usuario {
  Usuario({
    required this.id,
    required this.cpf,
    required this.nomeCompleto,
    this.email,
    this.telefone,
    required this.enderecoResidencial,
    this.enderecoTrabalho,
  });

  final String id;
  final String cpf;
  final String nomeCompleto;
  final String? email;
  final String? telefone;
  final Endereco enderecoResidencial;
  final Endereco? enderecoTrabalho;

  String get primeiroNome => nomeCompleto.split(' ').first;

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: j['id'],
        cpf: j['cpf'],
        nomeCompleto: j['nomeCompleto'],
        email: j['email'],
        telefone: j['telefone'],
        enderecoResidencial: Endereco.fromJson(j['enderecoResidencial']),
        enderecoTrabalho:
            j['enderecoTrabalho'] == null ? null : Endereco.fromJson(j['enderecoTrabalho']),
      );
}

/// Resposta do login/cadastro: token de acesso + dados do usuário.
class SessaoUsuario {
  SessaoUsuario(this.token, this.usuario);

  final String token;
  final Usuario usuario;

  factory SessaoUsuario.fromJson(Map<String, dynamic> j) =>
      SessaoUsuario(j['token'], Usuario.fromJson(j['usuario']));
}

class Fabricante {
  Fabricante(this.nome, this.logo);

  final String nome;
  final String? logo;

  String? get assetLogo => logo == null ? null : 'assets/montadoras/$logo';

  factory Fabricante.fromJson(Map<String, dynamic> j) => Fabricante(j['nome'], j['logo']);
}

class Veiculo {
  Veiculo({
    required this.id,
    required this.placa,
    required this.fabricante,
    this.fabricanteLogo,
    required this.modelo,
    required this.anoFabricacao,
    required this.cor,
    required this.kmAtual,
    this.dataKmAtual,
  });

  final String id;
  final String placa;
  final String fabricante;
  final String? fabricanteLogo;
  final String modelo;
  final int anoFabricacao;
  final String cor;
  final int kmAtual;
  final DateTime? dataKmAtual;

  String? get assetLogo => fabricanteLogo == null ? null : 'assets/montadoras/$fabricanteLogo';

  factory Veiculo.fromJson(Map<String, dynamic> j) => Veiculo(
        id: j['id'],
        placa: j['placa'],
        fabricante: j['fabricante'],
        fabricanteLogo: j['fabricanteLogo'],
        modelo: j['modelo'],
        anoFabricacao: j['anoFabricacao'],
        cor: j['cor'],
        kmAtual: j['kmAtual'],
        dataKmAtual: _data(j['dataKmAtual']),
      );
}

enum Situacao { semRegistro, emDia, proximo, vencido }

/// Qual parâmetro define o vencimento do item.
enum Referencia {
  ambos('Ambos', 'O que vencer 1º'),
  km('Km', 'Por km'),
  data('Data', 'Por data');

  const Referencia(this.api, this.rotulo);

  /// Valor usado na API.
  final String api;
  final String rotulo;

  bool get usaKm => this != Referencia.data;
  bool get usaData => this != Referencia.km;

  static Referencia de(String? v) => Referencia.values.firstWhere((r) => r.api == v, orElse: () => Referencia.ambos);
}

Situacao _situacao(String s) => switch (s) {
      'EmDia' => Situacao.emDia,
      'Proximo' => Situacao.proximo,
      'Vencido' => Situacao.vencido,
      _ => Situacao.semRegistro,
    };

class ItemManutencao {
  ItemManutencao({
    required this.id,
    this.codigoCatalogo,
    required this.nome,
    this.observacao,
    required this.personalizado,
    required this.referencia,
    this.intervaloKm,
    this.intervaloMeses,
    this.ultimaKm,
    this.ultimaData,
    required this.situacao,
    this.proximaKm,
    this.kmRestante,
    this.proximaData,
    this.diasRestantes,
  });

  final String id;
  final String? codigoCatalogo;
  final String nome;
  final String? observacao;
  final bool personalizado;
  final Referencia referencia;
  final int? intervaloKm;
  final int? intervaloMeses;
  final int? ultimaKm;
  final DateTime? ultimaData;
  final Situacao situacao;
  final int? proximaKm;
  final int? kmRestante;
  final DateTime? proximaData;
  final int? diasRestantes;

  factory ItemManutencao.fromJson(Map<String, dynamic> j) => ItemManutencao(
        id: j['id'],
        codigoCatalogo: j['codigoCatalogo'],
        nome: j['nome'],
        observacao: j['observacao'],
        personalizado: j['personalizado'],
        referencia: Referencia.de(j['referencia']),
        intervaloKm: j['intervaloKm'],
        intervaloMeses: j['intervaloMeses'],
        ultimaKm: j['ultimaKm'],
        ultimaData: _data(j['ultimaData']),
        situacao: _situacao(j['situacao']),
        proximaKm: j['proximaKm'],
        kmRestante: j['kmRestante'],
        proximaData: _data(j['proximaData']),
        diasRestantes: j['diasRestantes'],
      );
}

class Painel {
  Painel({
    required this.veiculo,
    required this.vencidos,
    required this.proximos,
    required this.semRegistro,
    required this.itens,
  });

  final Veiculo veiculo;
  final int vencidos;
  final int proximos;
  final int semRegistro;
  final List<ItemManutencao> itens;

  factory Painel.fromJson(Map<String, dynamic> j) => Painel(
        veiculo: Veiculo.fromJson(j['veiculo']),
        vencidos: j['vencidos'],
        proximos: j['proximos'],
        semRegistro: j['semRegistro'],
        itens: (j['itens'] as List).map((e) => ItemManutencao.fromJson(e)).toList(),
      );
}

class Manutencao {
  Manutencao({
    required this.id,
    required this.data,
    required this.km,
    required this.itens,
    this.descricao,
    this.valor,
    this.oficina,
  });

  final String id;
  final DateTime data;
  final int km;
  final List<String> itens;
  final String? descricao;
  final double? valor;
  final String? oficina;

  factory Manutencao.fromJson(Map<String, dynamic> j) => Manutencao(
        id: j['id'],
        data: DateTime.parse(j['data']),
        km: j['km'],
        itens: List<String>.from(j['itens']),
        descricao: j['descricao'],
        valor: (j['valor'] as num?)?.toDouble(),
        oficina: j['oficina'],
      );
}
