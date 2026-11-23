using TokMecanico.Api.Domain;

namespace TokMecanico.Api.Contracts;

// ---------- Entrada ----------

public record EnderecoRequest(
    string? Cep, string? Logradouro, string? Numero, string? Complemento,
    string? Bairro, string? Cidade, string? Uf);

/// <summary>Cadastro e edição de dados. Senha e aceite dos termos só são usados no cadastro.</summary>
public record UsuarioRequest(
    string? Cpf, string? NomeCompleto, string? Email, string? Telefone,
    EnderecoRequest? EnderecoResidencial, EnderecoRequest? EnderecoTrabalho,
    string? Senha = null, bool AceiteTermos = false);

public record LoginRequest(string? Cpf, string? Senha);

public record TrocaSenhaRequest(string? SenhaAtual, string? NovaSenha);

/// <summary>
/// DataReferencia/KmReferencia (só no cadastro): data da aquisição ou da última revisão e o km nessa data.
/// Servem para pré-preencher a última realização de todos os itens de manutenção.
/// </summary>
public record VeiculoRequest(
    string? Placa, string? Fabricante, string? Modelo, int? AnoFabricacao, string? Cor, int? KmAtual,
    DateOnly? DataReferencia = null, int? KmReferencia = null);

/// <summary>Conferência após o cadastro: itens que NÃO foram feitos na data de referência.</summary>
public record ConferenciaRequest(List<Guid>? SemRegistro);

public record ItemManutencaoRequest(
    string? Nome, string? Observacao, int? IntervaloKm, int? IntervaloMeses,
    int? UltimaKm, DateOnly? UltimaData, Referencia? Referencia = null);

public record RegistroKmRequest(int? Km, DateOnly? Data);

public record ManutencaoRequest(
    DateOnly? Data, int? Km, List<Guid>? ItensIds, string? Descricao, decimal? Valor, string? Oficina);

// ---------- Saída ----------

public record EnderecoResponse(
    string Cep, string Logradouro, string Numero, string? Complemento,
    string Bairro, string Cidade, string Uf)
{
    public static EnderecoResponse? De(Endereco? e) => e is null
        ? null
        : new(e.Cep, e.Logradouro, e.Numero, e.Complemento, e.Bairro, e.Cidade, e.Uf);
}

public record UsuarioResponse(
    Guid Id, string Cpf, string NomeCompleto, string? Email, string? Telefone,
    EnderecoResponse EnderecoResidencial, EnderecoResponse? EnderecoTrabalho, DateTime CriadoEm)
{
    public static UsuarioResponse De(Usuario u) => new(
        u.Id, u.Cpf, u.NomeCompleto, u.Email, u.Telefone,
        EnderecoResponse.De(u.EnderecoResidencial)!, EnderecoResponse.De(u.EnderecoTrabalho), u.CriadoEm);
}

public record SessaoResponse(string Token, DateTime ExpiraEm, UsuarioResponse Usuario);

public record VeiculoResponse(
    Guid Id, Guid UsuarioId, string Placa, string Fabricante, string? FabricanteLogo, string Modelo,
    int AnoFabricacao, string Cor, int KmAtual, DateOnly? DataKmAtual)
{
    public static VeiculoResponse De(Veiculo v) => new(
        v.Id, v.UsuarioId, v.Placa, v.Fabricante,
        Catalogos.Fabricantes.FirstOrDefault(f => f.Nome == v.Fabricante)?.Logo,
        v.Modelo, v.AnoFabricacao, v.Cor, v.KmAtual, v.DataKmAtual);
}

public record ItemManutencaoResponse(
    Guid Id, string? CodigoCatalogo, string Nome, string? Observacao, bool Personalizado,
    Referencia Referencia, int? IntervaloKm, int? IntervaloMeses, int? UltimaKm, DateOnly? UltimaData,
    Situacao Situacao, int? ProximaKm, int? KmRestante, DateOnly? ProximaData, int? DiasRestantes)
{
    public static ItemManutencaoResponse De(ItemManutencao i, int kmAtual, DateOnly hoje)
    {
        var s = StatusManutencao.Calcular(i, kmAtual, hoje);
        return new(i.Id, i.CodigoCatalogo, i.Nome, i.Observacao, i.Personalizado,
            i.Referencia, i.IntervaloKm, i.IntervaloMeses, i.UltimaKm, i.UltimaData,
            s.Situacao, s.ProximaKm, s.KmRestante, s.ProximaData, s.DiasRestantes);
    }
}

/// <summary>KmPorMes: ritmo de uso estimado pelo histórico de km (nulo se ainda não dá para estimar).</summary>
public record PainelResponse(
    VeiculoResponse Veiculo, int Vencidos, int Proximos, int SemRegistro,
    List<ItemManutencaoResponse> Itens, double? KmPorMes = null);

public record RegistroKmResponse(Guid Id, int Km, DateOnly Data)
{
    public static RegistroKmResponse De(RegistroKm r) => new(r.Id, r.Km, r.Data);
}

public record ManutencaoResponse(
    Guid Id, DateOnly Data, int Km, List<Guid> ItensIds, List<string> Itens,
    string? Descricao, decimal? Valor, string? Oficina);
