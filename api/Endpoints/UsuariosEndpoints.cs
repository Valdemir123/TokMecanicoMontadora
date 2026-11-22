using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TokMecanico.Api.Contracts;
using TokMecanico.Api.Data;
using TokMecanico.Api.Domain;

namespace TokMecanico.Api.Endpoints;

public static class UsuariosEndpoints
{
    public const string PoliticaLogin = "login";

    public static void MapUsuarios(this IEndpointRouteBuilder app)
    {
        var auth = app.MapGroup("/api/auth").WithTags("Login").RequireRateLimiting(PoliticaLogin);

        // Cadastro: cria o usuário e já devolve a sessão (token).
        auth.MapPost("/cadastro", async (UsuarioRequest req, TokMecanicoDbContext db,
            IOptions<JwtOpcoes> jwt, TimeProvider relogio) =>
        {
            var erros = Validar(req);
            if (Senhas.Problema(req.Senha) is { } problema) erros.Add("senha", problema);
            erros.Se(!req.AceiteTermos, "aceiteTermos", "É preciso aceitar os termos de uso e a política de privacidade.");
            if (erros.Tem) return erros.Resultado();

            var cpf = Validacoes.SomenteDigitos(req.Cpf);
            if (await db.Usuarios.AnyAsync(u => u.Cpf == cpf))
                return Results.Conflict(new { mensagem = "Já existe um cadastro com este CPF. Faça login." });

            var usuario = new Usuario
            {
                Cpf = cpf,
                SenhaHash = Senhas.Gerar(req.Senha!),
                AceiteTermosEm = relogio.GetUtcNow().UtcDateTime,
            };
            Aplicar(usuario, req);
            db.Usuarios.Add(usuario);
            await db.SaveChangesAsync();
            return Results.Created("/api/usuarios/me", Sessao(usuario, jwt.Value, relogio));
        });

        auth.MapPost("/login", async (LoginRequest req, TokMecanicoDbContext db,
            IOptions<JwtOpcoes> jwt, TimeProvider relogio) =>
        {
            var cpf = Validacoes.SomenteDigitos(req.Cpf);
            var usuario = await db.Usuarios.FirstOrDefaultAsync(u => u.Cpf == cpf);
            // Mesma resposta para CPF inexistente e senha errada (não revela quem tem cadastro).
            if (usuario is null || string.IsNullOrEmpty(req.Senha) || !Senhas.Conferir(req.Senha, usuario.SenhaHash))
                return Results.Json(new { mensagem = "CPF ou senha incorretos." }, statusCode: StatusCodes.Status401Unauthorized);
            return Results.Ok(Sessao(usuario, jwt.Value, relogio));
        });

        var me = app.MapGroup("/api/usuarios/me").WithTags("Usuários").RequireAuthorization();

        me.MapGet("/", async (HttpContext http, TokMecanicoDbContext db) =>
            await db.Usuarios.FindAsync(http.User.UsuarioId()) is { } u
                ? Results.Ok(UsuarioResponse.De(u))
                : Results.Unauthorized());

        me.MapPut("/", async (HttpContext http, UsuarioRequest req, TokMecanicoDbContext db) =>
        {
            if (await db.Usuarios.FindAsync(http.User.UsuarioId()) is not { } usuario) return Results.Unauthorized();

            var erros = Validar(req);
            // O CPF identifica o cadastro e não pode ser trocado.
            erros.Se(Validacoes.SomenteDigitos(req.Cpf) != usuario.Cpf, "cpf", "O CPF não pode ser alterado.");
            if (erros.Tem) return erros.Resultado();

            Aplicar(usuario, req);
            await db.SaveChangesAsync();
            return Results.Ok(UsuarioResponse.De(usuario));
        });

        me.MapPost("/senha", async (HttpContext http, TrocaSenhaRequest req, TokMecanicoDbContext db) =>
        {
            if (await db.Usuarios.FindAsync(http.User.UsuarioId()) is not { } usuario) return Results.Unauthorized();
            var e = new Erros();
            e.Se(string.IsNullOrEmpty(req.SenhaAtual) || !Senhas.Conferir(req.SenhaAtual, usuario.SenhaHash),
                "senhaAtual", "Senha atual incorreta.");
            if (Senhas.Problema(req.NovaSenha) is { } problema) e.Add("novaSenha", problema);
            if (e.Tem) return e.Resultado();
            usuario.SenhaHash = Senhas.Gerar(req.NovaSenha!);
            await db.SaveChangesAsync();
            return Results.NoContent();
        });
    }

    private static SessaoResponse Sessao(Usuario u, JwtOpcoes jwt, TimeProvider relogio) => new(
        Seguranca.GerarToken(u, jwt, relogio),
        relogio.GetUtcNow().UtcDateTime.AddDays(jwt.ValidadeDias),
        UsuarioResponse.De(u));

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
