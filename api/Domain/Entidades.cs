namespace TokMecanico.Api.Domain;

public class Usuario
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>CPF somente com dígitos (11 caracteres).</summary>
    public string Cpf { get; set; } = "";
    public string NomeCompleto { get; set; } = "";
    public string? Email { get; set; }
    public string? Telefone { get; set; }

    public Endereco EnderecoResidencial { get; set; } = new();
    public Endereco? EnderecoTrabalho { get; set; }

    /// <summary>Hash PBKDF2 da senha (ver <see cref="Senhas"/>). Nunca a senha em texto.</summary>
    public string SenhaHash { get; set; } = "";

    /// <summary>Quando o usuário aceitou os termos de uso e a política de privacidade (LGPD).</summary>
    public DateTime? AceiteTermosEm { get; set; }

    public DateTime CriadoEm { get; set; } = DateTime.UtcNow;

    public List<Veiculo> Veiculos { get; set; } = [];
}

/// <summary>Endereço brasileiro (gravado junto do usuário, como owned type).</summary>
public class Endereco
{
    /// <summary>CEP somente com dígitos (8 caracteres).</summary>
    public string Cep { get; set; } = "";
    public string Logradouro { get; set; } = "";
    public string Numero { get; set; } = "";
    public string? Complemento { get; set; }
    public string Bairro { get; set; } = "";
    public string Cidade { get; set; } = "";
    public string Uf { get; set; } = "";
}

public class Veiculo
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    /// <summary>Placa normalizada: maiúsculas, sem hífen (ABC1234 ou ABC1D23).</summary>
    public string Placa { get; set; } = "";
    public string Fabricante { get; set; } = "";
    public string Modelo { get; set; } = "";
    public int AnoFabricacao { get; set; }
    public string Cor { get; set; } = "";

    /// <summary>Último km conhecido (atualizado pelos registros de km e manutenções).</summary>
    public int KmAtual { get; set; }
    public DateOnly? DataKmAtual { get; set; }

    public DateTime CriadoEm { get; set; } = DateTime.UtcNow;

    public List<ItemManutencao> Itens { get; set; } = [];
    public List<RegistroKm> RegistrosKm { get; set; } = [];
    public List<Manutencao> Manutencoes { get; set; } = [];
}

/// <summary>
/// Item que o veículo precisa manter em dia (troca de óleo, pneus, etc.).
/// Pode vir do catálogo padrão ou ser um item pessoal criado pelo usuário.
/// </summary>
public class ItemManutencao
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid VeiculoId { get; set; }

    /// <summary>Código do catálogo (ex.: "oleo-motor"); nulo para itens pessoais.</summary>
    public string? CodigoCatalogo { get; set; }
    public string Nome { get; set; } = "";
    public string? Observacao { get; set; }

    /// <summary>A cada quantos km deve ser feito (nulo = não controla por km).</summary>
    public int? IntervaloKm { get; set; }
    /// <summary>A cada quantos meses deve ser feito (nulo = não controla por tempo).</summary>
    public int? IntervaloMeses { get; set; }

    public int? UltimaKm { get; set; }
    public DateOnly? UltimaData { get; set; }

    public bool Personalizado => CodigoCatalogo is null;
}

/// <summary>Leitura de hodômetro informada pelo usuário.</summary>
public class RegistroKm
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid VeiculoId { get; set; }
    public int Km { get; set; }
    public DateOnly Data { get; set; }
    public DateTime CriadoEm { get; set; } = DateTime.UtcNow;
}

/// <summary>Manutenção realizada (pode cobrir vários itens de uma vez).</summary>
public class Manutencao
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid VeiculoId { get; set; }
    public DateOnly Data { get; set; }
    public int Km { get; set; }
    public string? Descricao { get; set; }
    public decimal? Valor { get; set; }
    public string? Oficina { get; set; }

    /// <summary>Ids dos itens atendidos, separados por vírgula no banco.</summary>
    public List<Guid> ItensIds { get; set; } = [];
    public DateTime CriadoEm { get; set; } = DateTime.UtcNow;
}
