namespace TokMecanico.Api.Endpoints;

/// <summary>Acumula erros de validação por campo e gera um 400 (ValidationProblem).</summary>
public class Erros
{
    private readonly Dictionary<string, List<string>> _erros = new();

    public bool Tem => _erros.Count > 0;

    public void Add(string campo, string mensagem)
    {
        if (!_erros.TryGetValue(campo, out var lista))
            _erros[campo] = lista = [];
        lista.Add(mensagem);
    }

    public void Se(bool condicao, string campo, string mensagem)
    {
        if (condicao) Add(campo, mensagem);
    }

    public IResult Resultado() =>
        Results.ValidationProblem(_erros.ToDictionary(e => e.Key, e => e.Value.ToArray()),
            title: "Dados inválidos");
}
