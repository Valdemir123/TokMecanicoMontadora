using System.Text.RegularExpressions;

namespace TokMecanico.Api.Domain;

public static partial class Validacoes
{
    public static string SomenteDigitos(string? valor) =>
        valor is null ? "" : new string(valor.Where(char.IsAsciiDigit).ToArray());

    /// <summary>Valida CPF pelos dígitos verificadores. Aceita com ou sem máscara.</summary>
    public static bool CpfValido(string? cpf)
    {
        var d = SomenteDigitos(cpf);
        if (d.Length != 11 || d.Distinct().Count() == 1) return false;

        int Digito(int tamanho)
        {
            var soma = 0;
            for (var i = 0; i < tamanho; i++)
                soma += (d[i] - '0') * (tamanho + 1 - i);
            var resto = soma % 11;
            return resto < 2 ? 0 : 11 - resto;
        }

        return Digito(9) == d[9] - '0' && Digito(10) == d[10] - '0';
    }

    public static bool CepValido(string? cep) => SomenteDigitos(cep).Length == 8;

    /// <summary>Remove espaços e hífen e passa para maiúsculas.</summary>
    public static string NormalizarPlaca(string? placa) =>
        (placa ?? "").Replace("-", "").Replace(" ", "").Trim().ToUpperInvariant();

    /// <summary>Aceita o padrão antigo (ABC1234) e o Mercosul (ABC1D23).</summary>
    public static bool PlacaValida(string? placa) => PlacaRegex().IsMatch(NormalizarPlaca(placa));

    public static readonly string[] Ufs =
    [
        "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA",
        "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
    ];

    [GeneratedRegex("^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$")]
    private static partial Regex PlacaRegex();
}
