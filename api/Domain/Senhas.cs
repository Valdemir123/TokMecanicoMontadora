using System.Security.Cryptography;

namespace TokMecanico.Api.Domain;

/// <summary>Hash de senhas com PBKDF2-SHA256 e sal aleatório (formato "v1.iteracoes.sal.hash").</summary>
public static class Senhas
{
    private const int Iteracoes = 210_000;
    private const int TamanhoSal = 16;
    private const int TamanhoHash = 32;

    public const int TamanhoMinimo = 8;

    public static string Gerar(string senha)
    {
        var sal = RandomNumberGenerator.GetBytes(TamanhoSal);
        var hash = Rfc2898DeriveBytes.Pbkdf2(senha, sal, Iteracoes, HashAlgorithmName.SHA256, TamanhoHash);
        return $"v1.{Iteracoes}.{Convert.ToBase64String(sal)}.{Convert.ToBase64String(hash)}";
    }

    public static bool Conferir(string senha, string armazenado)
    {
        var partes = armazenado.Split('.');
        if (partes.Length != 4 || partes[0] != "v1" || !int.TryParse(partes[1], out var iteracoes)) return false;
        var sal = Convert.FromBase64String(partes[2]);
        var esperado = Convert.FromBase64String(partes[3]);
        var hash = Rfc2898DeriveBytes.Pbkdf2(senha, sal, iteracoes, HashAlgorithmName.SHA256, esperado.Length);
        return CryptographicOperations.FixedTimeEquals(hash, esperado);
    }

    /// <summary>Exige tamanho mínimo, ao menos uma letra e um número.</summary>
    public static string? Problema(string? senha)
    {
        if (string.IsNullOrEmpty(senha) || senha.Length < TamanhoMinimo)
            return $"A senha precisa ter pelo menos {TamanhoMinimo} caracteres.";
        if (!senha.Any(char.IsLetter) || !senha.Any(char.IsDigit))
            return "A senha precisa ter letras e números.";
        return null;
    }
}
