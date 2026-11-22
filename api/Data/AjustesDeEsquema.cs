using Microsoft.EntityFrameworkCore;

namespace TokMecanico.Api.Data;

/// <summary>
/// Acrescenta colunas novas a bancos criados por versões anteriores (enquanto usamos EnsureCreated).
/// Quando passarmos para migrations do EF Core, isto sai.
/// </summary>
public static class AjustesDeEsquema
{
    public static void Aplicar(TokMecanicoDbContext db)
    {
        if (!db.Database.IsSqlite()) return;
        AdicionarColuna(db, "ItensManutencao", "Referencia", "TEXT NOT NULL DEFAULT 'Ambos'",
            // itens antigos: referência natural pelos intervalos
            "UPDATE ItensManutencao SET Referencia = CASE " +
            "WHEN IntervaloKm IS NOT NULL AND IntervaloMeses IS NULL THEN 'Km' " +
            "WHEN IntervaloKm IS NULL AND IntervaloMeses IS NOT NULL THEN 'Data' ELSE 'Ambos' END");
    }

    private static void AdicionarColuna(TokMecanicoDbContext db, string tabela, string coluna, string definicao, string? depois = null)
    {
        var conexao = db.Database.GetDbConnection();
        conexao.Open();
        try
        {
            using var cmd = conexao.CreateCommand();
            cmd.CommandText = $"SELECT COUNT(*) FROM pragma_table_info('{tabela}') WHERE name = '{coluna}'";
            if (Convert.ToInt64(cmd.ExecuteScalar()) > 0) return;
            cmd.CommandText = $"ALTER TABLE {tabela} ADD COLUMN {coluna} {definicao}";
            cmd.ExecuteNonQuery();
            if (depois is not null)
            {
                cmd.CommandText = depois;
                cmd.ExecuteNonQuery();
            }
        }
        finally
        {
            conexao.Close();
        }
    }
}
