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
    public async Task Referencia_PadraoDoCatalogo_EPodeSerTrocada()
    {
        var (_, http) = await CriarUsuario("371.835.360-17");
        var v = await CriarVeiculo(http, km: 50_000);
        var itens = (await Painel(http, v.Id)).Itens;
        Assert.Equal(Referencia.Data, itens.Single(i => i.CodigoCatalogo == "bateria").Referencia);
        Assert.Equal(Referencia.Km, itens.Single(i => i.CodigoCatalogo == "pastilhas-freio").Referencia);
        var oleo = itens.Single(i => i.CodigoCatalogo == "oleo-motor");
        Assert.Equal(Referencia.Ambos, oleo.Referencia);

        // Óleo trocado há 13 meses com pouco km: vencido por data; ao marcar "por km" fica em dia.
        var r = await http.PutAsJsonAsync($"/api/veiculos/{v.Id}/itens/{oleo.Id}", new
        {
            nome = oleo.Nome, intervaloKm = 10_000, intervaloMeses = 12, ultimaKm = 48_000, ultimaData = "2025-10-01",
            referencia = "Km",
        });
        Assert.Equal(HttpStatusCode.OK, r.StatusCode);
        var item = (await r.Content.ReadFromJsonAsync<ItemManutencaoResponse>(Json))!;
        Assert.Equal(Referencia.Km, item.Referencia);
        Assert.Equal(Situacao.EmDia, item.Situacao);

        // "por data" sem intervalo em meses é recusado
        var invalido = await http.PutAsJsonAsync($"/api/veiculos/{v.Id}/itens/{oleo.Id}", new
        {
            nome = oleo.Nome, intervaloKm = 10_000, referencia = "Data",
        });
        Assert.Equal(HttpStatusCode.BadRequest, invalido.StatusCode);
    }

    [Fact]
    public async Task DataDeReferencia_PreencheItens_EConferenciaLimpaOsNaoFeitos()
    {
        var (_, http) = await CriarUsuario("820.137.415-02");
        var r = await http.PostAsJsonAsync("/api/veiculos", new
        {
            placa = "ABC1234", fabricante = "Honda", modelo = "Civic", anoFabricacao = 2019, cor = "Preto",
            kmAtual = 62_000, dataReferencia = "2026-03-01", kmReferencia = 55_000,
        });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        var v = (await r.Content.ReadFromJsonAsync<VeiculoResponse>(Json))!;

        var painel = await Painel(http, v.Id);
        Assert.Equal(0, painel.SemRegistro);
        Assert.All(painel.Itens, i => Assert.Equal(new DateOnly(2026, 3, 1), i.UltimaData));
        Assert.All(painel.Itens, i => Assert.Equal(55_000, i.UltimaKm));
        // óleo: 55.000 + 10.000 = 65.000; atual 62.000 -> faltam 3.000 km, em dia
        Assert.Equal(Situacao.EmDia, painel.Itens.Single(i => i.CodigoCatalogo == "oleo-motor").Situacao);
        // alinhamento por "o que vencer 1º": 03/2027 ou 65.000 km -> em dia
        // correia: 115.000 km / 03/2030 -> em dia

        var correia = painel.Itens.Single(i => i.CodigoCatalogo == "correia-dentada");
        var bateria = painel.Itens.Single(i => i.CodigoCatalogo == "bateria");
        var conf = await http.PostAsJsonAsync($"/api/veiculos/{v.Id}/itens/conferencia", new { semRegistro = new[] { correia.Id, bateria.Id } });
        Assert.Equal(HttpStatusCode.NoContent, conf.StatusCode);

        painel = await Painel(http, v.Id);
        Assert.Equal(2, painel.SemRegistro);
        Assert.Null(painel.Itens.Single(i => i.Id == correia.Id).UltimaData);

        var futura = await http.PostAsJsonAsync("/api/veiculos", new
        {
            placa = "XYZ9876", fabricante = "Honda", modelo = "Fit", anoFabricacao = 2019, cor = "Prata",
            kmAtual = 10_000, dataReferencia = "2027-01-01", kmReferencia = 20_000,
        });
        var corpo = await futura.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.BadRequest, futura.StatusCode);
        Assert.Contains("dataReferencia", corpo);
        Assert.Contains("kmReferencia", corpo);
    }

    [Fact]
    public async Task ExcluirRevisao_RestauraEstadoAnterior_EKmPorMes()
    {
        var (_, http) = await CriarUsuario("596.317.802-95");
        var r = await http.PostAsJsonAsync("/api/veiculos", new
        {
            placa = "DEF5678", fabricante = "Nissan", modelo = "Kicks", anoFabricacao = 2025, cor = "Branco",
            kmAtual = 17_000, dataReferencia = "2026-01-10", kmReferencia = 5_000,
        });
        var v = (await r.Content.ReadFromJsonAsync<VeiculoResponse>(Json))!;
        var oleo = (await Painel(http, v.Id)).Itens.Single(i => i.CodigoCatalogo == "oleo-motor");

        async Task<Guid> Revisao(string data, int km)
        {
            var resp = await http.PostAsJsonAsync($"/api/veiculos/{v.Id}/manutencoes", new { data, km, itensIds = new[] { oleo.Id } });
            return (await resp.Content.ReadFromJsonAsync<ManutencaoResponse>(Json))!.Id;
        }
        var primeira = await Revisao("2026-06-10", 11_000);
        var segunda = await Revisao("2026-11-10", 17_000);
        Assert.Equal(17_000, (await Painel(http, v.Id)).Itens.Single(i => i.Id == oleo.Id).UltimaKm);

        // 5.000 km em 10/01 -> 17.000 km em 10/11 (304 dias): ~1.201 km/mês
        var kmMes = (await Painel(http, v.Id)).KmPorMes;
        Assert.InRange(kmMes!.Value, 1_150, 1_250);

        // excluir a mais recente volta para a anterior
        Assert.Equal(HttpStatusCode.NoContent, (await http.DeleteAsync($"/api/veiculos/{v.Id}/manutencoes/{segunda}")).StatusCode);
        var item = (await Painel(http, v.Id)).Itens.Single(i => i.Id == oleo.Id);
        Assert.Equal(11_000, item.UltimaKm);
        Assert.Equal(new DateOnly(2026, 6, 10), item.UltimaData);

        // excluir a única restante volta para a data de referência do cadastro
        await http.DeleteAsync($"/api/veiculos/{v.Id}/manutencoes/{primeira}");
        item = (await Painel(http, v.Id)).Itens.Single(i => i.Id == oleo.Id);
        Assert.Equal(5_000, item.UltimaKm);
        Assert.Equal(new DateOnly(2026, 1, 10), item.UltimaData);
        Assert.Empty((await http.GetFromJsonAsync<List<ManutencaoResponse>>($"/api/veiculos/{v.Id}/manutencoes", Json))!);
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
