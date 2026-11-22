using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using TokMecanico.Api.Data;
using TokMecanico.Api.Domain;
using TokMecanico.Api.Endpoints;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();
builder.Services.AddSingleton(TimeProvider.System);

builder.Services.AddDbContext<TokMecanicoDbContext>(o =>
    o.UseSqlite(builder.Configuration.GetConnectionString("TokMecanico")));

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
    scope.ServiceProvider.GetRequiredService<TokMecanicoDbContext>().Database.EnsureCreated();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}
else
{
    app.UseHttpsRedirection();
}

app.UseCors();

app.MapGet("/api/fabricantes", () => Catalogos.Fabricantes).WithTags("Catálogos");
app.MapGet("/api/catalogo-manutencoes", () => Catalogos.ItensPadrao).WithTags("Catálogos");
app.MapUsuarios();
app.MapVeiculos();
app.MapManutencoes();

app.Run();

public partial class Program;
