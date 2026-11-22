using TokMecanico.Api.Domain;

namespace TokMecanico.Api.Tests;

public class ValidacoesTests
{
    [Theory]
    [InlineData("529.982.247-25", true)]
    [InlineData("52998224725", true)]
    [InlineData("529.982.247-24", false)]
    [InlineData("111.111.111-11", false)]
    [InlineData("1234567890", false)]
    [InlineData(null, false)]
    public void Cpf(string? cpf, bool esperado) => Assert.Equal(esperado, Validacoes.CpfValido(cpf));

    [Theory]
    [InlineData("ABC1234", true)]
    [InlineData("abc-1234", true)]
    [InlineData("BRA2E19", true)]
    [InlineData("AB12345", false)]
    [InlineData("ABC12345", false)]
    [InlineData("", false)]
    public void Placa(string placa, bool esperado) => Assert.Equal(esperado, Validacoes.PlacaValida(placa));

    [Theory]
    [InlineData("01310-100", true)]
    [InlineData("0131010", false)]
    public void Cep(string cep, bool esperado) => Assert.Equal(esperado, Validacoes.CepValido(cep));
}

public class StatusManutencaoTests
{
    private static readonly DateOnly Hoje = new(2026, 11, 22);

    private static ItemManutencao Oleo(int? ultimaKm, DateOnly? ultimaData) => new()
    {
        Nome = "Óleo", IntervaloKm = 10_000, IntervaloMeses = 12, UltimaKm = ultimaKm, UltimaData = ultimaData,
    };

    [Fact]
    public void SemHistorico_SemRegistro()
    {
        var s = StatusManutencao.Calcular(Oleo(null, null), 50_000, Hoje);
        Assert.Equal(Situacao.SemRegistro, s.Situacao);
        Assert.Null(s.ProximaKm);
    }

    [Fact]
    public void FeitoRecentemente_EmDia()
    {
        var s = StatusManutencao.Calcular(Oleo(48_000, new(2026, 9, 1)), 50_000, Hoje);
        Assert.Equal(Situacao.EmDia, s.Situacao);
        Assert.Equal(58_000, s.ProximaKm);
        Assert.Equal(8_000, s.KmRestante);
        Assert.Equal(new DateOnly(2027, 9, 1), s.ProximaData);
    }

    [Fact]
    public void FaltandoPoucosKm_Proximo()
    {
        var s = StatusManutencao.Calcular(Oleo(40_500, new(2026, 9, 1)), 50_000, Hoje);
        Assert.Equal(Situacao.Proximo, s.Situacao);
        Assert.Equal(500, s.KmRestante);
    }

    [Fact]
    public void PassouDoKm_Vencido()
    {
        var s = StatusManutencao.Calcular(Oleo(38_000, new(2026, 9, 1)), 50_000, Hoje);
        Assert.Equal(Situacao.Vencido, s.Situacao);
        Assert.Equal(-2_000, s.KmRestante);
    }

    [Fact]
    public void PassouDoPrazo_VencidoMesmoComKmSobrando()
    {
        var s = StatusManutencao.Calcular(Oleo(49_000, new(2025, 10, 1)), 50_000, Hoje);
        Assert.Equal(Situacao.Vencido, s.Situacao);
    }

    [Fact]
    public void SoPorTempo_FaltandoMenosDe30Dias_Proximo()
    {
        var bateria = new ItemManutencao { Nome = "Bateria", IntervaloMeses = 36, UltimaData = new(2023, 12, 10) };
        var s = StatusManutencao.Calcular(bateria, 50_000, Hoje);
        Assert.Equal(Situacao.Proximo, s.Situacao);
        Assert.Equal(18, s.DiasRestantes);
        Assert.Null(s.KmRestante);
    }
}
