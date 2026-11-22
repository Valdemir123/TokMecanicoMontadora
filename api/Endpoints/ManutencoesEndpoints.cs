using Microsoft.EntityFrameworkCore;
using TokMecanico.Api.Contracts;
using TokMecanico.Api.Data;
using TokMecanico.Api.Domain;

namespace TokMecanico.Api.Endpoints;

/// <summary>Itens de manutenção, registros de km e manutenções realizadas de um veículo.</summary>
public static class ManutencoesEndpoints
{
    public static void MapManutencoes(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/veiculos/{veiculoId:guid}").WithTags("Manutenções");

        // ---------- Itens (padrão e pessoais) ----------

        g.MapPost("/itens", async (Guid veiculoId, ItemManutencaoRequest req, TokMecanicoDbContext db, TimeProvider relogio) =>
        {
            if (await db.Veiculos.FindAsync(veiculoId) is not { } veiculo) return Results.NotFound();

            var erros = ValidarItem(req, relogio);
            if (erros.Tem) return erros.Resultado();

            var item = new ItemManutencao { VeiculoId = veiculoId };
            AplicarItem(item, req);
            db.ItensManutencao.Add(item);
            await db.SaveChangesAsync();
            return Results.Created($"/api/veiculos/{veiculoId}/itens/{item.Id}",
                ItemManutencaoResponse.De(item, veiculo.KmAtual, VeiculosEndpoints.Hoje(relogio)));
        });

        g.MapPut("/itens/{itemId:guid}", async (Guid veiculoId, Guid itemId, ItemManutencaoRequest req,
            TokMecanicoDbContext db, TimeProvider relogio) =>
        {
            if (await db.Veiculos.FindAsync(veiculoId) is not { } veiculo) return Results.NotFound();
            var item = await db.ItensManutencao.FirstOrDefaultAsync(i => i.Id == itemId && i.VeiculoId == veiculoId);
            if (item is null) return Results.NotFound();

            var erros = ValidarItem(req, relogio);
            if (erros.Tem) return erros.Resultado();

            AplicarItem(item, req);
            await db.SaveChangesAsync();
            return Results.Ok(ItemManutencaoResponse.De(item, veiculo.KmAtual, VeiculosEndpoints.Hoje(relogio)));
        });

        g.MapDelete("/itens/{itemId:guid}", async (Guid veiculoId, Guid itemId, TokMecanicoDbContext db) =>
        {
            var item = await db.ItensManutencao.FirstOrDefaultAsync(i => i.Id == itemId && i.VeiculoId == veiculoId);
            if (item is null) return Results.NotFound();
            db.ItensManutencao.Remove(item);
            await db.SaveChangesAsync();
            return Results.NoContent();
        });

        // ---------- Km ----------

        g.MapGet("/km", async (Guid veiculoId, TokMecanicoDbContext db) =>
        {
            if (!await db.Veiculos.AnyAsync(v => v.Id == veiculoId)) return Results.NotFound();
            var registros = await db.RegistrosKm.Where(r => r.VeiculoId == veiculoId)
                .OrderByDescending(r => r.Data).ThenByDescending(r => r.Km).ToListAsync();
            return Results.Ok(registros.Select(RegistroKmResponse.De));
        });

        g.MapPost("/km", async (Guid veiculoId, RegistroKmRequest req, TokMecanicoDbContext db, TimeProvider relogio) =>
        {
            if (await db.Veiculos.FindAsync(veiculoId) is not { } veiculo) return Results.NotFound();

            var hoje = VeiculosEndpoints.Hoje(relogio);
            var data = req.Data ?? hoje;
            var e = new Erros();
            e.Se(req.Km is not { } km || km < 0 || km > VeiculosEndpoints.KmMaximo, "km", "Km inválido.");
            e.Se(data > hoje, "data", "A data não pode ser no futuro.");
            e.Se(req.Km < veiculo.KmAtual, "km",
                $"O km não pode ser menor que o último registrado ({veiculo.KmAtual:N0} km).");
            if (e.Tem) return e.Resultado();

            var registro = new RegistroKm { VeiculoId = veiculoId, Km = req.Km!.Value, Data = data };
            db.RegistrosKm.Add(registro);
            AtualizarKm(veiculo, registro.Km, data);
            await db.SaveChangesAsync();
            return Results.Created($"/api/veiculos/{veiculoId}/km", RegistroKmResponse.De(registro));
        });

        // ---------- Manutenções realizadas ----------

        g.MapGet("/manutencoes", async (Guid veiculoId, TokMecanicoDbContext db) =>
        {
            if (!await db.Veiculos.AnyAsync(v => v.Id == veiculoId)) return Results.NotFound();
            var nomes = await db.ItensManutencao.Where(i => i.VeiculoId == veiculoId)
                .ToDictionaryAsync(i => i.Id, i => i.Nome);
            var lista = await db.Manutencoes.Where(m => m.VeiculoId == veiculoId)
                .OrderByDescending(m => m.Data).ThenByDescending(m => m.Km).ToListAsync();
            return Results.Ok(lista.Select(m => ParaResponse(m, nomes)));
        });

        g.MapPost("/manutencoes", async (Guid veiculoId, ManutencaoRequest req, TokMecanicoDbContext db, TimeProvider relogio) =>
        {
            var veiculo = await db.Veiculos.Include(v => v.Itens).FirstOrDefaultAsync(v => v.Id == veiculoId);
            if (veiculo is null) return Results.NotFound();

            var hoje = VeiculosEndpoints.Hoje(relogio);
            var ids = (req.ItensIds ?? []).Distinct().ToList();
            var itens = veiculo.Itens.Where(i => ids.Contains(i.Id)).ToList();

            var e = new Erros();
            e.Se(req.Data is null, "data", "Informe a data.");
            e.Se(req.Data > hoje, "data", "A data não pode ser no futuro.");
            e.Se(req.Km is not { } km || km < 0 || km > VeiculosEndpoints.KmMaximo, "km", "Km inválido.");
            e.Se(ids.Count == 0 && string.IsNullOrWhiteSpace(req.Descricao), "itensIds",
                "Selecione ao menos um item ou descreva o serviço.");
            e.Se(itens.Count != ids.Count, "itensIds", "Algum item não pertence a este veículo.");
            e.Se(req.Valor < 0, "valor", "Valor inválido.");
            if (e.Tem) return e.Resultado();

            var manutencao = new Manutencao
            {
                VeiculoId = veiculoId,
                Data = req.Data!.Value,
                Km = req.Km!.Value,
                ItensIds = ids,
                Descricao = string.IsNullOrWhiteSpace(req.Descricao) ? null : req.Descricao.Trim(),
                Valor = req.Valor,
                Oficina = string.IsNullOrWhiteSpace(req.Oficina) ? null : req.Oficina.Trim(),
            };
            db.Manutencoes.Add(manutencao);

            // Atualiza a "última realização" só se esta manutenção for a mais recente do item.
            foreach (var item in itens.Where(i => i.UltimaData is null || i.UltimaData <= manutencao.Data))
            {
                item.UltimaData = manutencao.Data;
                item.UltimaKm = manutencao.Km;
            }

            AtualizarKm(veiculo, manutencao.Km, manutencao.Data);
            await db.SaveChangesAsync();
            return Results.Created($"/api/veiculos/{veiculoId}/manutencoes/{manutencao.Id}",
                ParaResponse(manutencao, itens.ToDictionary(i => i.Id, i => i.Nome)));
        });
    }

    /// <summary>O km atual do veículo só avança (nunca volta).</summary>
    private static void AtualizarKm(Veiculo veiculo, int km, DateOnly data)
    {
        if (km < veiculo.KmAtual) return;
        veiculo.KmAtual = km;
        if (veiculo.DataKmAtual is null || data > veiculo.DataKmAtual) veiculo.DataKmAtual = data;
    }

    private static Erros ValidarItem(ItemManutencaoRequest req, TimeProvider relogio)
    {
        var e = new Erros();
        e.Se(string.IsNullOrWhiteSpace(req.Nome), "nome", "Informe o nome do item.");
        e.Se(req.Nome?.Trim().Length > 100, "nome", "Máximo de 100 caracteres.");
        e.Se(req.IntervaloKm is null && req.IntervaloMeses is null, "intervaloKm",
            "Informe o intervalo em km, em meses ou ambos.");
        e.Se(req.IntervaloKm is <= 0 or > 500_000, "intervaloKm", "Intervalo de km inválido.");
        e.Se(req.IntervaloMeses is <= 0 or > 240, "intervaloMeses", "Intervalo de meses inválido.");
        e.Se(req.UltimaKm is < 0 or > VeiculosEndpoints.KmMaximo, "ultimaKm", "Km inválido.");
        e.Se(req.UltimaData > VeiculosEndpoints.Hoje(relogio), "ultimaData", "A data não pode ser no futuro.");
        return e;
    }

    private static void AplicarItem(ItemManutencao item, ItemManutencaoRequest req)
    {
        item.Nome = req.Nome!.Trim();
        item.Observacao = string.IsNullOrWhiteSpace(req.Observacao) ? null : req.Observacao.Trim();
        item.IntervaloKm = req.IntervaloKm;
        item.IntervaloMeses = req.IntervaloMeses;
        item.UltimaKm = req.UltimaKm;
        item.UltimaData = req.UltimaData;
    }

    private static ManutencaoResponse ParaResponse(Manutencao m, IReadOnlyDictionary<Guid, string> nomes) => new(
        m.Id, m.Data, m.Km, m.ItensIds,
        m.ItensIds.Select(id => nomes.GetValueOrDefault(id, "(item removido)")).ToList(),
        m.Descricao, m.Valor, m.Oficina);
}
