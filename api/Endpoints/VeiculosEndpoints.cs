using Microsoft.EntityFrameworkCore;
using TokMecanico.Api.Contracts;
using TokMecanico.Api.Data;
using TokMecanico.Api.Domain;

namespace TokMecanico.Api.Endpoints;

public static class VeiculosEndpoints
{
    public const int KmMaximo = 2_000_000;

    public static void MapVeiculos(this IEndpointRouteBuilder app)
    {
        // Veículos do usuário logado.
        var meus = app.MapGroup("/api/veiculos").WithTags("Veículos").RequireAuthorization();

        meus.MapGet("/", async (HttpContext http, TokMecanicoDbContext db) =>
        {
            var usuarioId = http.User.UsuarioId();
            var veiculos = await db.Veiculos.Where(v => v.UsuarioId == usuarioId)
                .OrderBy(v => v.CriadoEm).ToListAsync();
            return Results.Ok(veiculos.Select(VeiculoResponse.De));
        });

        meus.MapPost("/", async (HttpContext http, VeiculoRequest req, TokMecanicoDbContext db, TimeProvider relogio) =>
        {
            var usuarioId = http.User.UsuarioId();

            var erros = Validar(req, relogio);
            var hojeV = Hoje(relogio);
            erros.Se(req.DataReferencia > hojeV, "dataReferencia", "A data não pode ser no futuro.");
            erros.Se(req.KmReferencia is < 0 or > KmMaximo, "kmReferencia", "Km inválido.");
            erros.Se(req.KmReferencia > req.KmAtual, "kmReferencia", "O km nessa data não pode ser maior que o km atual.");
            if (erros.Tem) return erros.Resultado();

            var placa = Validacoes.NormalizarPlaca(req.Placa);
            if (await db.Veiculos.AnyAsync(v => v.UsuarioId == usuarioId && v.Placa == placa))
                return Results.Conflict(new { mensagem = "Você já cadastrou um veículo com esta placa." });

            var hoje = Hoje(relogio);
            var veiculo = new Veiculo { UsuarioId = usuarioId, Placa = placa };
            Aplicar(veiculo, req);
            veiculo.KmAtual = req.KmAtual ?? 0;
            veiculo.DataKmAtual = req.KmAtual is null ? null : hoje;

            // Todo veículo nasce com os itens padrão. Com a data de referência (aquisição ou última
            // revisão), a última realização de cada item já vem preenchida; o usuário confere depois.
            var kmRef = req.DataReferencia is null ? (int?)null : req.KmReferencia ?? req.KmAtual ?? 0;
            veiculo.Itens.AddRange(Catalogos.ItensPadrao.Select(c => new ItemManutencao
            {
                CodigoCatalogo = c.Codigo,
                Nome = c.Nome,
                Observacao = c.Observacao,
                IntervaloKm = c.IntervaloKm,
                IntervaloMeses = c.IntervaloMeses,
                Referencia = ReferenciaPadrao.De(c.IntervaloKm, c.IntervaloMeses),
                UltimaData = req.DataReferencia,
                UltimaKm = kmRef,
            }));
            if (req.KmAtual is { } km)
                veiculo.RegistrosKm.Add(new RegistroKm { Km = km, Data = hoje });

            db.Veiculos.Add(veiculo);
            await db.SaveChangesAsync();
            return Results.Created($"/api/veiculos/{veiculo.Id}", VeiculoResponse.De(veiculo));
        });

        var g = app.MapGroup("/api/veiculos/{id:guid}").WithTags("Veículos").SomenteVeiculoDoUsuario("id");

        g.MapGet("/", async (Guid id, TokMecanicoDbContext db) =>
            await db.Veiculos.FindAsync(id) is { } v ? Results.Ok(VeiculoResponse.De(v)) : Results.NotFound());

        g.MapPut("/", async (Guid id, VeiculoRequest req, TokMecanicoDbContext db, TimeProvider relogio) =>
        {
            if (await db.Veiculos.FindAsync(id) is not { } veiculo) return Results.NotFound();

            var erros = Validar(req, relogio);
            var placa = Validacoes.NormalizarPlaca(req.Placa);
            if (!erros.Tem && placa != veiculo.Placa &&
                await db.Veiculos.AnyAsync(v => v.UsuarioId == veiculo.UsuarioId && v.Placa == placa))
                erros.Add("placa", "Você já cadastrou um veículo com esta placa.");
            if (erros.Tem) return erros.Resultado();

            veiculo.Placa = placa;
            Aplicar(veiculo, req);
            // O km atual só muda por registro de km ou manutenção, para manter o histórico coerente.
            await db.SaveChangesAsync();
            return Results.Ok(VeiculoResponse.De(veiculo));
        });

        g.MapDelete("/", async (Guid id, TokMecanicoDbContext db) =>
        {
            if (await db.Veiculos.FindAsync(id) is not { } veiculo) return Results.NotFound();
            db.Veiculos.Remove(veiculo);
            await db.SaveChangesAsync();
            return Results.NoContent();
        });

        // Painel: todos os itens com a situação calculada, os mais urgentes primeiro.
        g.MapGet("/painel", async (Guid id, TokMecanicoDbContext db, TimeProvider relogio) =>
        {
            var veiculo = await db.Veiculos.Include(v => v.Itens).FirstOrDefaultAsync(v => v.Id == id);
            if (veiculo is null) return Results.NotFound();

            var hoje = Hoje(relogio);
            var itens = veiculo.Itens
                .Select(i => ItemManutencaoResponse.De(i, veiculo.KmAtual, hoje))
                .OrderBy(i => i.Situacao switch
                {
                    Situacao.Vencido => 0,
                    Situacao.Proximo => 1,
                    Situacao.SemRegistro => 2,
                    _ => 3,
                })
                .ThenBy(i => i.KmRestante ?? int.MaxValue)
                .ThenBy(i => i.DiasRestantes ?? int.MaxValue)
                .ThenBy(i => i.Nome)
                .ToList();

            return Results.Ok(new PainelResponse(
                VeiculoResponse.De(veiculo),
                itens.Count(i => i.Situacao == Situacao.Vencido),
                itens.Count(i => i.Situacao == Situacao.Proximo),
                itens.Count(i => i.Situacao == Situacao.SemRegistro),
                itens));
        });
    }

    internal static DateOnly Hoje(TimeProvider relogio) => DateOnly.FromDateTime(relogio.GetLocalNow().DateTime);

    private static Erros Validar(VeiculoRequest req, TimeProvider relogio)
    {
        var e = new Erros();
        var anoMaximo = Hoje(relogio).Year + 1;
        e.Se(!Validacoes.PlacaValida(req.Placa), "placa", "Placa inválida. Use ABC1234 ou ABC1D23.");
        e.Se(string.IsNullOrWhiteSpace(req.Fabricante), "fabricante", "Informe o fabricante.");
        e.Se(string.IsNullOrWhiteSpace(req.Modelo), "modelo", "Informe o modelo.");
        e.Se(req.AnoFabricacao is not { } ano || ano < 1900 || ano > anoMaximo,
            "anoFabricacao", $"Ano deve estar entre 1900 e {anoMaximo}.");
        e.Se(string.IsNullOrWhiteSpace(req.Cor), "cor", "Informe a cor.");
        e.Se(req.KmAtual is < 0 or > KmMaximo, "kmAtual", "Km inválido.");
        return e;
    }

    private static void Aplicar(Veiculo v, VeiculoRequest req)
    {
        // Usa o nome oficial do catálogo quando o fabricante for conhecido (ex.: "fiat" -> "Fiat").
        var fabricante = req.Fabricante!.Trim();
        v.Fabricante = Catalogos.Fabricantes
            .FirstOrDefault(f => string.Equals(f.Nome, fabricante, StringComparison.OrdinalIgnoreCase))?.Nome
            ?? fabricante;
        v.Modelo = req.Modelo!.Trim();
        v.AnoFabricacao = req.AnoFabricacao!.Value;
        v.Cor = req.Cor!.Trim();
    }
}
