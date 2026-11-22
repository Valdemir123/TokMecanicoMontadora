using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using TokMecanico.Api.Data;
using TokMecanico.Api.Domain;
using TokMecanico.Api.Endpoints;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();
builder.Services.AddSingleton(TimeProvider.System);

builder.Services.AddDbContext<TokMecanicoDbContext>(o =>
    o.UseSqlite(builder.Configuration.GetConnectionString("TokMecanico")));

// Login com token JWT. A chave vem de "Jwt:Chave" (em produção: variável de ambiente Jwt__Chave).
var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOpcoes>() ?? new JwtOpcoes();
if (jwt.Chave.Length < 32)
    throw new InvalidOperationException("Configure Jwt:Chave com pelo menos 32 caracteres (variável de ambiente Jwt__Chave).");
builder.Services.Configure<JwtOpcoes>(builder.Configuration.GetSection("Jwt"));
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
{
    o.MapInboundClaims = false;
    o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidIssuer = JwtOpcoes.Emissor,
        ValidAudience = JwtOpcoes.Emissor,
        IssuerSigningKey = jwt.ChaveAssinatura(),
        ClockSkew = TimeSpan.FromMinutes(1),
    };
});
builder.Services.AddAuthorization();

// Limita tentativas de login/cadastro por IP (contra quem tenta adivinhar senhas).
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy(UsuariosEndpoints.PoliticaLogin, http => RateLimitPartition.GetFixedWindowLimiter(
        http.Connection.RemoteIpAddress?.ToString() ?? "desconhecido",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = builder.Configuration.GetValue("Login:TentativasPorMinuto", 10),
            Window = TimeSpan.FromMinutes(1),
        }));
});

builder.Services.ConfigureHttpJsonOptions(o =>
    o.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));

// O site (Flutter Web) roda em outra origem; as origens liberadas ficam em "Cors:Origens".
var origens = builder.Configuration.GetSection("Cors:Origens").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
{
    if (origens.Contains("*")) p.AllowAnyOrigin();
    else p.WithOrigins(origens);
    p.AllowAnyHeader().AllowAnyMethod();
}));

var app = builder.Build();

// MVP: cria o banco na primeira execução. Trocar por migrations antes de ir para produção.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<TokMecanicoDbContext>();
    db.Database.EnsureCreated();
    AjustesDeEsquema.Aplicar(db);
}

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}
else
{
    app.UseHttpsRedirection();
}

app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/fabricantes", () => Catalogos.Fabricantes).WithTags("Catálogos");
app.MapGet("/api/catalogo-manutencoes", () => Catalogos.ItensPadrao).WithTags("Catálogos");
app.MapUsuarios();
app.MapVeiculos();
app.MapManutencoes();

app.Run();

public partial class Program;
