using Microsoft.EntityFrameworkCore;
using TokMecanico.Api.Contracts;
using TokMecanico.Api.Data;
using TokMecanico.Api.Domain;

namespace TokMecanico.Api.Endpoints;

public static class UsuariosEndpoints
{
    public static void MapUsuarios(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/usuarios").WithTags("Usuários");

        g.MapPost("/", async (UsuarioRequest req, TokMecanicoDbContext db) =>
        {
            var erros = Validar(req);
            if (erros.Tem) return erros.Resultado();

            var cpf = Validacoes.SomenteDigitos(req.Cpf);
            if (await db.Usuarios.AnyAsync(u => u.Cpf == cpf))
                return Results.Conflict(new { mensagem = "Já existe um cadastro com este CPF." });

            var usuario = new Usuario { Cpf = cpf };
            Aplicar(usuario, req);
            db.Usuarios.Add(usuario);
            await db.SaveChangesAsync();
            return Results.Created($"/api/usuarios/{usuario.Id}", UsuarioResponse.De(usuario));
        });

        g.MapGet("/{id:guid}", async (Guid id, TokMecanicoDbContext db) =>
            await db.Usuarios.FindAsync(id) is { } u
                ? Results.Ok(UsuarioResponse.De(u))
                : Results.NotFound());

        g.MapPut("/{id:guid}", async (Guid id, UsuarioRequest req, TokMecanicoDbContext db) =>
        {
            if (await db.Usuarios.FindAsync(id) is not { } usuario) return Results.NotFound();

            var erros = Validar(req);
            // O CPF identifica o cadastro e não pode ser trocado.
            erros.Se(Validacoes.SomenteDigitos(req.Cpf) != usuario.Cpf, "cpf", "O CPF não pode ser alterado.");
            if (erros.Tem) return erros.Resultado();

            Aplicar(usuario, req);
            await db.SaveChangesAsync();
            return Results.Ok(UsuarioResponse.De(usuario));
        });
    }

    private static Erros Validar(UsuarioRequest req)
    {
        var e = new Erros();
        e.Se(!Validacoes.CpfValido(req.Cpf), "cpf", "CPF inválido.");
        e.Se(string.IsNullOrWhiteSpace(req.NomeCompleto), "nomeCompleto", "Informe o nome completo.");
        e.Se(req.NomeCompleto?.Trim().Length > 150, "nomeCompleto", "Máximo de 150 caracteres.");
        e.Se(!string.IsNullOrWhiteSpace(req.Email) && !req.Email.Contains('@'), "email", "E-mail inválido.");

        if (req.EnderecoResidencial is null)
            e.Add("enderecoResidencial", "Informe o endereço residencial.");
        else
            ValidarEndereco(e, "enderecoResidencial", req.EnderecoResidencial);

        if (req.EnderecoTrabalho is not null)
            ValidarEndereco(e, "enderecoTrabalho", req.EnderecoTrabalho);
        return e;
    }

    private static void ValidarEndereco(Erros e, string prefixo, EnderecoRequest end)
    {
        e.Se(!Validacoes.CepValido(end.Cep), $"{prefixo}.cep", "CEP inválido.");
        e.Se(string.IsNullOrWhiteSpace(end.Logradouro), $"{prefixo}.logradouro", "Informe o logradouro.");
        e.Se(string.IsNullOrWhiteSpace(end.Numero), $"{prefixo}.numero", "Informe o número (ou S/N).");
        e.Se(string.IsNullOrWhiteSpace(end.Bairro), $"{prefixo}.bairro", "Informe o bairro.");
        e.Se(string.IsNullOrWhiteSpace(end.Cidade), $"{prefixo}.cidade", "Informe a cidade.");
        e.Se(!Validacoes.Ufs.Contains(end.Uf?.Trim().ToUpperInvariant()), $"{prefixo}.uf", "UF inválida.");
    }

    private static void Aplicar(Usuario u, UsuarioRequest req)
    {
        u.NomeCompleto = req.NomeCompleto!.Trim();
        u.Email = string.IsNullOrWhiteSpace(req.Email) ? null : req.Email.Trim().ToLowerInvariant();
        u.Telefone = string.IsNullOrWhiteSpace(req.Telefone) ? null : Validacoes.SomenteDigitos(req.Telefone);
        u.EnderecoResidencial = ParaEndereco(req.EnderecoResidencial!);
        u.EnderecoTrabalho = req.EnderecoTrabalho is null ? null : ParaEndereco(req.EnderecoTrabalho);
    }

    private static Endereco ParaEndereco(EnderecoRequest r) => new()
    {
        Cep = Validacoes.SomenteDigitos(r.Cep),
        Logradouro = r.Logradouro!.Trim(),
        Numero = r.Numero!.Trim(),
        Complemento = string.IsNullOrWhiteSpace(r.Complemento) ? null : r.Complemento.Trim(),
        Bairro = r.Bairro!.Trim(),
        Cidade = r.Cidade!.Trim(),
        Uf = r.Uf!.Trim().ToUpperInvariant(),
    };
}
