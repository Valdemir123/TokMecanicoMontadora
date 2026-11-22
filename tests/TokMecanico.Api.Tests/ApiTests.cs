using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using TokMecanico.Api.Contracts;
using TokMecanico.Api.Domain;

namespace TokMecanico.Api.Tests;

/// <summary>Sobe a API com um banco SQLite temporário e "hoje" fixo em 22/11/2026.</summary>
public class ApiFactory : WebApplicationFactory<Program>
{
    private readonly string _banco = Path.Combine(Path.GetTempPath(), $"tokmecanico-{Guid.NewGuid():N}.db");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("ConnectionStrings:TokMecanico", $"Data Source={_banco};Pooling=False");
        builder.ConfigureServices(s => s.Replace(ServiceDescriptor.Singleton<TimeProvider>(new RelogioFixo())));
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        File.Delete(_banco);
    }

    private class RelogioFixo : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(2026, 11, 22, 12, 0, 0, TimeSpan.Zero);
        public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.Utc;
    }
}

public class ApiTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() },
    };

    private readonly HttpClient _http = factory.CreateClient();

    private static object Endereco(string cep = "01310-100") => new
    {
        cep, logradouro = "Av. Paulista", numero = "1000", bairro = "Bela Vista", cidade = "São Paulo", uf = "sp",
    };

    private async Task<UsuarioResponse> CriarUsuario(string cpf)
    {
        var r = await _http.PostAsJsonAsync("/api/usuarios", new
        {
            cpf, nomeCompleto = "Maria da Silva", enderecoResidencial = Endereco(), enderecoTrabalho = Endereco("20040-020"),
        });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        return (await r.Content.ReadFromJsonAsync<UsuarioResponse>(Json))!;
    }

    private async Task<VeiculoResponse> CriarVeiculo(Guid usuarioId, int km = 50_000)
    {
        var r = await _http.PostAsJsonAsync($"/api/usuarios/{usuarioId}/veiculos", new
        {
            placa = "bra-2e19", fabricante = "fiat", modelo = "Argo 1.0", anoFabricacao = 2021, cor = "Prata", kmAtual = km,
        });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        return (await r.Content.ReadFromJsonAsync<VeiculoResponse>(Json))!;
    }

    private async Task<PainelResponse> Painel(Guid veiculoId) =>
        (await _http.GetFromJsonAsync<PainelResponse>($"/api/veiculos/{veiculoId}/painel", Json))!;

    [Fact]
    public async Task Cadastro_NormalizaDados_EBloqueiaCpfDuplicado()
    {
        var u = await CriarUsuario("529.982.247-25");
        Assert.Equal("52998224725", u.Cpf);
        Assert.Equal("01310100", u.EnderecoResidencial.Cep);
        Assert.Equal("SP", u.EnderecoResidencial.Uf);
        Assert.Equal("20040020", u.EnderecoTrabalho!.Cep);

        var dup = await _http.PostAsJsonAsync("/api/usuarios", new
        {
            cpf = "52998224725", nomeCompleto = "Outra Pessoa", enderecoResidencial = Endereco(),
        });
        Assert.Equal(HttpStatusCode.Conflict, dup.StatusCode);
    }

    [Fact]
    public async Task Cadastro_DadosInvalidos_Retorna400ComCampos()
    {
        var r = await _http.PostAsJsonAsync("/api/usuarios", new
        {
            cpf = "123", nomeCompleto = "", enderecoResidencial = new { cep = "1" },
        });
        Assert.Equal(HttpStatusCode.BadRequest, r.StatusCode);
        var corpo = await r.Content.ReadAsStringAsync();
        Assert.Contains("\"cpf\"", corpo);
        Assert.Contains("nomeCompleto", corpo);
        Assert.Contains("enderecoResidencial.cep", corpo);
    }

    [Fact]
    public async Task Veiculo_NasceComItensPadraoSemRegistro()
    {
        var u = await CriarUsuario("390.533.447-05");
        var v = await CriarVeiculo(u.Id);
        Assert.Equal("BRA2E19", v.Placa);
        Assert.Equal("Fiat", v.Fabricante);
        Assert.Equal("imgFiat.png", v.FabricanteLogo);

        var painel = await Painel(v.Id);
        Assert.Equal(Catalogos.ItensPadrao.Count, painel.Itens.Count);
        Assert.Equal(painel.Itens.Count, painel.SemRegistro);
    }

    [Fact]
    public async Task Manutencao_AtualizaItemKmEPainel()
    {
        var u = await CriarUsuario("111.444.777-35");
        var v = await CriarVeiculo(u.Id, km: 50_000);
        var oleo = (await Painel(v.Id)).Itens.Single(i => i.CodigoCatalogo == "oleo-motor");

        var r = await _http.PostAsJsonAsync($"/api/veiculos/{v.Id}/manutencoes", new
        {
            data = "2026-11-20", km = 51_000, itensIds = new[] { oleo.Id }, valor = 280.50m, oficina = "Auto Center",
        });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);

        var painel = await Painel(v.Id);
        Assert.Equal(51_000, painel.Veiculo.KmAtual);
        var oleoDepois = painel.Itens.Single(i => i.Id == oleo.Id);
        Assert.Equal(Situacao.EmDia, oleoDepois.Situacao);
        Assert.Equal(61_000, oleoDepois.ProximaKm);

        var historico = await _http.GetFromJsonAsync<List<ManutencaoResponse>>($"/api/veiculos/{v.Id}/manutencoes", Json);
        Assert.Equal("Troca de óleo do motor", Assert.Single(historico!).Itens.Single());
    }

    [Fact]
    public async Task Km_NaoPodeVoltar_EAtualizaSituacao()
    {
        var u = await CriarUsuario("935.411.347-80");
        var v = await CriarVeiculo(u.Id, km: 50_000);

        var menor = await _http.PostAsJsonAsync($"/api/veiculos/{v.Id}/km", new { km = 49_000 });
        Assert.Equal(HttpStatusCode.BadRequest, menor.StatusCode);

        // Item pessoal: lavagem a cada 1.500 km, feita nos 50.000 km.
        var item = await _http.PostAsJsonAsync($"/api/veiculos/{v.Id}/itens", new
        {
            nome = "Lavagem do motor", intervaloKm = 1_500, ultimaKm = 50_000, ultimaData = "2026-11-01",
        });
        var criado = (await item.Content.ReadFromJsonAsync<ItemManutencaoResponse>(Json))!;
        Assert.True(criado.Personalizado);
        Assert.Equal(Situacao.EmDia, criado.Situacao);

        var maior = await _http.PostAsJsonAsync($"/api/veiculos/{v.Id}/km", new { km = 52_000 });
        Assert.Equal(HttpStatusCode.Created, maior.StatusCode);

        var painel = await Painel(v.Id);
        Assert.Equal(Situacao.Vencido, painel.Itens.Single(i => i.Id == criado.Id).Situacao);
        Assert.Equal(1, painel.Vencidos);
        Assert.Equal(criado.Id, painel.Itens[0].Id);
    }
}
