using System.Net;
using System.Net.Http.Headers;
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

    protected virtual int TentativasPorMinuto => 1000;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("ConnectionStrings:TokMecanico", $"Data Source={_banco};Pooling=False");
        builder.UseSetting("Login:TentativasPorMinuto", TentativasPorMinuto.ToString());
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

public class ApiFactoryLimitada : ApiFactory
{
    protected override int TentativasPorMinuto => 3;
}

public class ApiTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    internal static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() },
    };

    private const string Senha = "segredo123";

    internal static object Endereco(string cep = "01310-100") => new
    {
        cep, logradouro = "Av. Paulista", numero = "1000", bairro = "Bela Vista", cidade = "São Paulo", uf = "sp",
    };

    internal static object Cadastro(string cpf, string? senha = Senha, bool aceite = true) => new
    {
        cpf, nomeCompleto = "Maria da Silva", enderecoResidencial = Endereco(), enderecoTrabalho = Endereco("20040-020"),
        senha, aceiteTermos = aceite,
    };

    /// <summary>Cadastra e devolve um cliente HTTP já autenticado com o token.</summary>
    private async Task<(SessaoResponse Sessao, HttpClient Http)> CriarUsuario(string cpf)
    {
        var r = await factory.CreateClient().PostAsJsonAsync("/api/auth/cadastro", Cadastro(cpf));
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        var sessao = (await r.Content.ReadFromJsonAsync<SessaoResponse>(Json))!;
        var http = factory.CreateClient();
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", sessao.Token);
        return (sessao, http);
    }

    private static async Task<VeiculoResponse> CriarVeiculo(HttpClient http, int km = 50_000)
    {
        var r = await http.PostAsJsonAsync("/api/veiculos", new
        {
            placa = "bra-2e19", fabricante = "fiat", modelo = "Argo 1.0", anoFabricacao = 2021, cor = "Prata", kmAtual = km,
        });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        return (await r.Content.ReadFromJsonAsync<VeiculoResponse>(Json))!;
    }

    private static async Task<PainelResponse> Painel(HttpClient http, Guid veiculoId) =>
        (await http.GetFromJsonAsync<PainelResponse>($"/api/veiculos/{veiculoId}/painel", Json))!;

    // ---------- Cadastro e login ----------

    [Fact]
    public async Task Cadastro_NormalizaDados_EBloqueiaCpfDuplicado()
    {
        var (sessao, _) = await CriarUsuario("529.982.247-25");
        Assert.False(string.IsNullOrEmpty(sessao.Token));
        Assert.Equal("52998224725", sessao.Usuario.Cpf);
        Assert.Equal("01310100", sessao.Usuario.EnderecoResidencial.Cep);
        Assert.Equal("SP", sessao.Usuario.EnderecoResidencial.Uf);
        Assert.Equal("20040020", sessao.Usuario.EnderecoTrabalho!.Cep);

        var dup = await factory.CreateClient().PostAsJsonAsync("/api/auth/cadastro", Cadastro("52998224725"));
        Assert.Equal(HttpStatusCode.Conflict, dup.StatusCode);
    }

    [Fact]
    public async Task Cadastro_DadosInvalidos_Retorna400ComCampos()
    {
        var r = await factory.CreateClient().PostAsJsonAsync("/api/auth/cadastro", new
        {
            cpf = "123", nomeCompleto = "", enderecoResidencial = new { cep = "1" }, senha = "curta", aceiteTermos = false,
        });
        Assert.Equal(HttpStatusCode.BadRequest, r.StatusCode);
        var corpo = await r.Content.ReadAsStringAsync();
        Assert.Contains("\"cpf\"", corpo);
        Assert.Contains("nomeCompleto", corpo);
        Assert.Contains("enderecoResidencial.cep", corpo);
        Assert.Contains("\"senha\"", corpo);
        Assert.Contains("aceiteTermos", corpo);
    }

    [Fact]
    public async Task Login_SenhaCerta_DevolveToken_SenhaErrada_401()
    {
        await CriarUsuario("390.533.447-05");
        var http = factory.CreateClient();

        var ok = await http.PostAsJsonAsync("/api/auth/login", new { cpf = "390.533.447-05", senha = Senha });
        Assert.Equal(HttpStatusCode.OK, ok.StatusCode);
        var sessao = (await ok.Content.ReadFromJsonAsync<SessaoResponse>(Json))!;
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", sessao.Token);
        var eu = await http.GetFromJsonAsync<UsuarioResponse>("/api/usuarios/me", Json);
        Assert.Equal("39053344705", eu!.Cpf);

        var errada = await factory.CreateClient().PostAsJsonAsync("/api/auth/login", new { cpf = "39053344705", senha = "outra123" });
        Assert.Equal(HttpStatusCode.Unauthorized, errada.StatusCode);
        var inexistente = await factory.CreateClient().PostAsJsonAsync("/api/auth/login", new { cpf = "11144477735", senha = Senha });
        Assert.Equal(HttpStatusCode.Unauthorized, inexistente.StatusCode);
    }

    [Fact]
    public async Task SemLogin_RotasProtegidas_401()
    {
        var http = factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await http.GetAsync("/api/usuarios/me")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await http.GetAsync("/api/veiculos")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await http.GetAsync($"/api/veiculos/{Guid.NewGuid()}/painel")).StatusCode);

        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "token-falso");
        Assert.Equal(HttpStatusCode.Unauthorized, (await http.GetAsync("/api/veiculos")).StatusCode);
    }

    [Fact]
    public async Task VeiculoDeOutroUsuario_NaoApareceNemPodeSerAlterado()
    {
        var (_, dono) = await CriarUsuario("714.602.380-01");
        var (_, outro) = await CriarUsuario("046.454.286-32");
        var v = await CriarVeiculo(dono);

        Assert.Empty((await outro.GetFromJsonAsync<List<VeiculoResponse>>("/api/veiculos", Json))!);
        Assert.Equal(HttpStatusCode.NotFound, (await outro.GetAsync($"/api/veiculos/{v.Id}/painel")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await outro.DeleteAsync($"/api/veiculos/{v.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await outro.PostAsJsonAsync($"/api/veiculos/{v.Id}/km", new { km = 99_000 })).StatusCode);

        // O dono continua vendo o veículo intacto.
        Assert.Equal(50_000, (await Painel(dono, v.Id)).Veiculo.KmAtual);
    }

    [Fact]
    public async Task TrocaDeSenha()
    {
        var (_, http) = await CriarUsuario("861.231.520-41");
        var errada = await http.PostAsJsonAsync("/api/usuarios/me/senha", new { senhaAtual = "nao123456", novaSenha = "novaSenha9" });
        Assert.Equal(HttpStatusCode.BadRequest, errada.StatusCode);

        var ok = await http.PostAsJsonAsync("/api/usuarios/me/senha", new { senhaAtual = Senha, novaSenha = "novaSenha9" });
        Assert.Equal(HttpStatusCode.NoContent, ok.StatusCode);

        var login = await factory.CreateClient().PostAsJsonAsync("/api/auth/login", new { cpf = "86123152041", senha = "novaSenha9" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
    }

    // ---------- Veículos e manutenções ----------

    [Fact]
    public async Task Veiculo_NasceComItensPadraoSemRegistro()
    {
        var (_, http) = await CriarUsuario("111.444.777-35");
        var v = await CriarVeiculo(http);
        Assert.Equal("BRA2E19", v.Placa);
        Assert.Equal("Fiat", v.Fabricante);
        Assert.Equal("imgFiat.png", v.FabricanteLogo);

        var painel = await Painel(http, v.Id);
        Assert.Equal(Catalogos.ItensPadrao.Count, painel.Itens.Count);
        Assert.Equal(painel.Itens.Count, painel.SemRegistro);
    }

    [Fact]
    public async Task Manutencao_AtualizaItemKmEPainel()
    {
        var (_, http) = await CriarUsuario("935.411.347-80");
        var v = await CriarVeiculo(http, km: 50_000);
        var oleo = (await Painel(http, v.Id)).Itens.Single(i => i.CodigoCatalogo == "oleo-motor");

        var r = await http.PostAsJsonAsync($"/api/veiculos/{v.Id}/manutencoes", new
        {
            data = "2026-11-20", km = 51_000, itensIds = new[] { oleo.Id }, valor = 280.50m, oficina = "Auto Center",
        });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);

        var painel = await Painel(http, v.Id);
        Assert.Equal(51_000, painel.Veiculo.KmAtual);
        var oleoDepois = painel.Itens.Single(i => i.Id == oleo.Id);
        Assert.Equal(Situacao.EmDia, oleoDepois.Situacao);
        Assert.Equal(61_000, oleoDepois.ProximaKm);

        var historico = await http.GetFromJsonAsync<List<ManutencaoResponse>>($"/api/veiculos/{v.Id}/manutencoes", Json);
        Assert.Equal("Troca de óleo do motor", Assert.Single(historico!).Itens.Single());
    }

    [Fact]
    public async Task Km_NaoPodeVoltar_EAtualizaSituacao()
    {
        var (_, http) = await CriarUsuario("248.438.034-80");
        var v = await CriarVeiculo(http, km: 50_000);

        var menor = await http.PostAsJsonAsync($"/api/veiculos/{v.Id}/km", new { km = 49_000 });
        Assert.Equal(HttpStatusCode.BadRequest, menor.StatusCode);

        // Item pessoal: lavagem a cada 1.500 km, feita nos 50.000 km.
        var item = await http.PostAsJsonAsync($"/api/veiculos/{v.Id}/itens", new
        {
            nome = "Lavagem do motor", intervaloKm = 1_500, ultimaKm = 50_000, ultimaData = "2026-11-01",
        });
        var criado = (await item.Content.ReadFromJsonAsync<ItemManutencaoResponse>(Json))!;
        Assert.True(criado.Personalizado);
        Assert.Equal(Situacao.EmDia, criado.Situacao);

        var maior = await http.PostAsJsonAsync($"/api/veiculos/{v.Id}/km", new { km = 52_000 });
        Assert.Equal(HttpStatusCode.Created, maior.StatusCode);

        var painel = await Painel(http, v.Id);
        Assert.Equal(Situacao.Vencido, painel.Itens.Single(i => i.Id == criado.Id).Situacao);
        Assert.Equal(1, painel.Vencidos);
        Assert.Equal(criado.Id, painel.Itens[0].Id);
    }
}

public class LimiteDeTentativasTests(ApiFactoryLimitada factory) : IClassFixture<ApiFactoryLimitada>
{
    [Fact]
    public async Task MuitasTentativasDeLogin_Retorna429()
    {
        var http = factory.CreateClient();
        var status = new List<HttpStatusCode>();
        for (var i = 0; i < 5; i++)
            status.Add((await http.PostAsJsonAsync("/api/auth/login", new { cpf = "52998224725", senha = "errada123" })).StatusCode);

        Assert.Equal([HttpStatusCode.Unauthorized, HttpStatusCode.Unauthorized, HttpStatusCode.Unauthorized,
            (HttpStatusCode)429, (HttpStatusCode)429], status);
    }
}
