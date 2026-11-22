using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using TokMecanico.Api.Data;
using TokMecanico.Api.Domain;

namespace TokMecanico.Api.Endpoints;

public class JwtOpcoes
{
    public const string Emissor = "TokMecanico";

    /// <summary>Chave de assinatura (mínimo 32 caracteres). Em produção vem de variável de ambiente.</summary>
    public string Chave { get; set; } = "";
    public int ValidadeDias { get; set; } = 30;

    public SymmetricSecurityKey ChaveAssinatura() => new(Encoding.UTF8.GetBytes(Chave));
}

public static class Seguranca
{
    /// <summary>Id do usuário logado (claim "sub" do token).</summary>
    public static Guid UsuarioId(this ClaimsPrincipal user) =>
        Guid.Parse(user.FindFirstValue(JwtRegisteredClaimNames.Sub)
                   ?? throw new InvalidOperationException("Usuário não autenticado."));

    public static string GerarToken(Usuario u, JwtOpcoes opcoes, TimeProvider relogio)
    {
        var agora = relogio.GetUtcNow().UtcDateTime;
        return new JsonWebTokenHandler().CreateToken(new SecurityTokenDescriptor
        {
            Issuer = JwtOpcoes.Emissor,
            Audience = JwtOpcoes.Emissor,
            Subject = new ClaimsIdentity([
                new Claim(JwtRegisteredClaimNames.Sub, u.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.Name, u.NomeCompleto),
            ]),
            IssuedAt = agora,
            NotBefore = agora,
            Expires = agora.AddDays(opcoes.ValidadeDias),
            SigningCredentials = new SigningCredentials(opcoes.ChaveAssinatura(), SecurityAlgorithms.HmacSha256),
        });
    }

    /// <summary>
    /// Exige login em todo o grupo e garante que o veículo da rota ({parametro}) pertence ao
    /// usuário logado. Veículo de outra pessoa responde 404, sem revelar que ele existe.
    /// </summary>
    public static RouteGroupBuilder SomenteVeiculoDoUsuario(this RouteGroupBuilder g, string parametro)
    {
        g.RequireAuthorization();
        g.AddEndpointFilter(async (ctx, next) =>
        {
            var http = ctx.HttpContext;
            if (!Guid.TryParse(http.Request.RouteValues[parametro]?.ToString(), out var veiculoId))
                return Results.NotFound();
            var db = http.RequestServices.GetRequiredService<TokMecanicoDbContext>();
            var usuarioId = http.User.UsuarioId();
            if (!await db.Veiculos.AnyAsync(v => v.Id == veiculoId && v.UsuarioId == usuarioId))
                return Results.NotFound();
            return await next(ctx);
        });
        return g;
    }
}
