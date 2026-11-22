# Tok Mecânico

Controle de manutenções veiculares.

| Pasta | O que é |
|---|---|
| `api/` | Backend em ASP.NET Core (.NET 10) + EF Core/SQLite |
| `app/` | Site responsivo e app (Flutter: Web, Android e iOS no mesmo código) |
| `tests/TokMecanico.Api.Tests/` | Testes da API (xUnit) |

## Módulos

1. **Cadastro e controle (pronto, primeira versão)**
   - Usuário: CPF (validado), nome completo, e-mail e celular opcionais, endereço residencial e de trabalho (o CEP preenche o endereço via ViaCEP).
   - Veículo: placa (antiga ou Mercosul), fabricante (com logo), modelo, ano de fabricação, cor e km atual.
   - Manutenções: cada veículo já nasce com 14 itens padrão (óleo, filtros, freios, correia, pneus, bateria…). O usuário pode ajustar os intervalos e criar itens pessoais.
   - Painel com a situação de cada item: **vencido**, **próximo** (faltam ≤ 1.000 km/10% do intervalo ou ≤ 30 dias), **em dia** ou **sem registro**.
   - Registro de km e de manutenções realizadas (com valor e oficina), e histórico com total gasto.
2. **App de entrada rápida de km e manutenções**: a base já está pronta no mesmo app Flutter.
3. **Lojas e mecânicos (a fazer)**: publicam serviços e produtos, que são cruzados com o que cada veículo precisa.

## Como rodar (Windows)

Pré-requisitos: .NET SDK 10 e Flutter.

**API** (fica em http://localhost:5153):

```powershell
cd D:\Projetos\TokMecanico\api
dotnet run
```

O banco `tokmecanico.db` (SQLite) é criado sozinho na primeira execução. A documentação OpenAPI fica em http://localhost:5153/openapi/v1.json, e `api/TokMecanico.Api.http` tem exemplos de chamadas.

**Site / app** (em outro terminal):

```powershell
cd D:\Projetos\TokMecanico\app
flutter pub get
flutter run -d chrome
```

No emulador Android, a API do computador fica em `10.0.2.2`:

```powershell
flutter run --dart-define=API_URL=http://10.0.2.2:5153
```

**Testes:**

```powershell
dotnet test TokMecanico.slnx
cd app; flutter test
```

## Principais rotas da API

| Método | Rota | Para quê |
|---|---|---|
| GET | `/api/fabricantes` | Montadoras e logos |
| POST/GET/PUT | `/api/usuarios`, `/api/usuarios/{id}` | Cadastro do usuário |
| GET/POST | `/api/usuarios/{id}/veiculos` | Veículos do usuário |
| GET/PUT/DELETE | `/api/veiculos/{id}` | Um veículo |
| GET | `/api/veiculos/{id}/painel` | Itens com a situação calculada |
| POST/PUT/DELETE | `/api/veiculos/{id}/itens[/{itemId}]` | Itens de manutenção (padrão e pessoais) |
| GET/POST | `/api/veiculos/{id}/km` | Leituras do hodômetro |
| GET/POST | `/api/veiculos/{id}/manutencoes` | Manutenções realizadas |

## Pendências antes de publicar

- **Login/autenticação**: hoje o app guarda o id do usuário no aparelho e a API não exige login. Como há CPF e endereço (dados pessoais, LGPD), isso precisa estar pronto antes de ir ao ar.
- Termo de uso e consentimento (LGPD).
- Trocar `EnsureCreated` por migrations do EF Core e definir o banco de produção (ex.: PostgreSQL).
