using TokMecanico.Api.Domain;

namespace TokMecanico.Api.Data;

/// <summary>Tarefas de administrador executadas pela linha de comando no servidor.</summary>
public static class Administracao
{
    /// <summary>Redefine a senha de um usuário. Retorna 0 em caso de sucesso.</summary>
    public static int RedefinirSenha(TokMecanicoDbContext db, string cpf, string novaSenha)
    {
        var digitos = Validacoes.SomenteDigitos(cpf);
        var usuario = db.Usuarios.FirstOrDefault(u => u.Cpf == digitos);
        if (usuario is null)
        {
            Console.Error.WriteLine($"Nenhum cadastro com o CPF {cpf}.");
            return 1;
        }
        if (Senhas.Problema(novaSenha) is { } problema)
        {
            Console.Error.WriteLine(problema);
            return 2;
        }
        usuario.SenhaHash = Senhas.Gerar(novaSenha);
        db.SaveChanges();
        Console.WriteLine($"Senha de {usuario.NomeCompleto} redefinida.");
        return 0;
    }
}
