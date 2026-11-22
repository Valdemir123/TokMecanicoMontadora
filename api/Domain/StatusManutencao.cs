namespace TokMecanico.Api.Domain;

public enum Situacao
{
    /// <summary>Nunca foi informada a última realização.</summary>
    SemRegistro,
    EmDia,
    /// <summary>Faltam poucos km ou poucos dias.</summary>
    Proximo,
    Vencido,
}

public record StatusItem(
    Situacao Situacao,
    int? ProximaKm,
    int? KmRestante,
    DateOnly? ProximaData,
    int? DiasRestantes);

public static class StatusManutencao
{
    /// <summary>Dias de antecedência para avisar que o item está próximo.</summary>
    public const int DiasAviso = 30;
    /// <summary>Km mínimo de antecedência para avisar (ou 10% do intervalo, o que for maior).</summary>
    public const int KmAvisoMinimo = 1_000;

    public static StatusItem Calcular(ItemManutencao item, int kmAtual, DateOnly hoje)
    {
        int? proximaKm = item is { IntervaloKm: { } ik, UltimaKm: { } uk } ? uk + ik : null;
        int? kmRestante = proximaKm - kmAtual;

        DateOnly? proximaData = item is { IntervaloMeses: { } im, UltimaData: { } ud } ? ud.AddMonths(im) : null;
        int? diasRestantes = proximaData is { } pd ? pd.DayNumber - hoje.DayNumber : null;

        Situacao situacao;
        if (proximaKm is null && proximaData is null)
        {
            situacao = Situacao.SemRegistro;
        }
        else if (kmRestante <= 0 || diasRestantes <= 0)
        {
            situacao = Situacao.Vencido;
        }
        else
        {
            var kmAviso = Math.Max(KmAvisoMinimo, (item.IntervaloKm ?? 0) / 10);
            situacao = kmRestante <= kmAviso || diasRestantes <= DiasAviso
                ? Situacao.Proximo
                : Situacao.EmDia;
        }

        return new StatusItem(situacao, proximaKm, kmRestante, proximaData, diasRestantes);
    }
}
