namespace TokMecanico.Api.Domain;

public record FabricanteInfo(string Nome, string? Logo);

public record ItemCatalogo(string Codigo, string Nome, int? IntervaloKm, int? IntervaloMeses, string? Observacao = null);

public static class Catalogos
{
    /// <summary>Montadoras com logo disponível em app/assets/montadoras/.</summary>
    public static readonly IReadOnlyList<FabricanteInfo> Fabricantes =
    [
        new("Acura", "imgAcura.png"),
        new("Alfa Romeo", "imgAlfaRomeo.png"),
        new("Audi", "imgAudi.png"),
        new("BMW", "imgBMW.png"),
        new("Chevrolet", "imgChevrolet.png"),
        new("Citroën", "imgCitroen.png"),
        new("Daewoo", "imgDaewoo.png"),
        new("Fiat", "imgFiat.png"),
        new("Ford", "imgFord.png"),
        new("Holden", "imgHolden.png"),
        new("Honda", "imgHonda.png"),
        new("Hyundai", "imgHyundai.png"),
        new("Jeep", "imgJeep.png"),
        new("Kia", "imgKia.png"),
        new("Land Rover", "imgLandRover.png"),
        new("Lexus", "imgLexus.png"),
        new("Mazda", "imgMazda.png"),
        new("Mercedes-Benz", "imgMercedesBens.png"),
        new("MG", "imgMG.png"),
        new("Mini", "imgMini.png"),
        new("Mitsubishi", "imgMitsubishi.png"),
        new("Nissan", "imgNissan.png"),
        new("Peugeot", "imgPeugeot.png"),
        new("Porsche", "imgPorsche.png"),
        new("Renault", "imgRenault.png"),
        new("Saab", "imgSaab.png"),
        new("Subaru", "imgSubaru.png"),
        new("Suzuki", "imgSuzuki.png"),
        new("Volkswagen", "imgVolkswagen.png"),
        new("Volvo", "imgVolvo.png"),
    ];

    /// <summary>
    /// Itens criados automaticamente para todo veículo novo. Os intervalos são
    /// referências comuns de mercado; o usuário pode ajustá-los conforme o manual
    /// do seu veículo.
    /// </summary>
    public static readonly IReadOnlyList<ItemCatalogo> ItensPadrao =
    [
        new("oleo-motor", "Troca de óleo do motor", 10_000, 12),
        new("filtro-oleo", "Filtro de óleo", 10_000, 12),
        new("filtro-ar", "Filtro de ar do motor", 15_000, 12),
        new("filtro-combustivel", "Filtro de combustível", 20_000, 24),
        new("filtro-cabine", "Filtro de ar-condicionado (cabine)", 15_000, 12),
        new("alinhamento", "Alinhamento e balanceamento", 10_000, 12),
        new("pastilhas-freio", "Pastilhas de freio", 30_000, null, "Verificar desgaste a cada revisão"),
        new("fluido-freio", "Fluido de freio", null, 24),
        new("arrefecimento", "Líquido de arrefecimento", 40_000, 24),
        new("correia-dentada", "Correia dentada", 60_000, 48, "Não se aplica a motores com corrente"),
        new("velas", "Velas de ignição", 40_000, 36),
        new("pneus", "Pneus", 50_000, 60, "Verificar calibragem a cada 15 dias"),
        new("bateria", "Bateria", null, 36),
        new("revisao-geral", "Revisão geral", 10_000, 12),
    ];
}
