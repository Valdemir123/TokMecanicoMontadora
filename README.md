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

O banco `tokmecanico.db` (SQLite) é criado sozinho na primeira execução. Se você já tinha um banco de uma versão anterior, apague `api/tokmecanico.db` antes de rodar (a estrutura mudou com o login). A documentação OpenAPI fica em http://localhost:5153/openapi/v1.json, e `api/TokMecanico.Api.http` tem exemplos de chamadas.

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

Todas as rotas, exceto cadastro, login e catálogos, exigem o cabeçalho `Authorization: Bearer <token>`. Cada usuário só acessa os próprios dados: veículo de outra pessoa responde 404.

| Método | Rota | Para quê |
|---|---|---|
| POST | `/api/auth/cadastro` | Cria a conta (dados + senha + aceite dos termos) e devolve o token |
| POST | `/api/auth/login` | Entra com CPF e senha e devolve o token (limite de 10 tentativas/min por IP) |
| GET/PUT | `/api/usuarios/me` | Ver e editar os próprios dados |
| POST | `/api/usuarios/me/senha` | Trocar a senha |
| GET | `/api/fabricantes` | Montadoras e logos |
| GET/POST | `/api/veiculos` | Veículos do usuário logado |
| GET/PUT/DELETE | `/api/veiculos/{id}` | Um veículo |
| GET | `/api/veiculos/{id}/painel` | Itens com a situação calculada |
| POST/PUT/DELETE | `/api/veiculos/{id}/itens[/{itemId}]` | Itens de manutenção (padrão e pessoais) |
| GET/POST | `/api/veiculos/{id}/km` | Leituras do hodômetro |
| GET/POST | `/api/veiculos/{id}/manutencoes` | Manutenções realizadas |

### Login e segurança

- Senhas guardadas só como hash PBKDF2-SHA256 com sal; mínimo de 8 caracteres, com letras e números.
- Token JWT válido por 30 dias (`Jwt:ValidadeDias`). A chave de assinatura fica em `Jwt:Chave`: em desenvolvimento vem do `appsettings.Development.json`; **em produção, defina a variável de ambiente `Jwt__Chave`** com um valor longo e secreto (a API não sobe sem ela).
- O aceite dos termos (LGPD) é obrigatório no cadastro e a data fica gravada.
- **Redefinir a senha de alguém** (enquanto não existe "Esqueci minha senha"): com a API parada, na pasta `api`:
  `dotnet run -- redefinir-senha 529.982.247-25 NovaSenha123`

## Pendências antes de publicar

- **Texto dos termos de uso e da política de privacidade**: o app mostra uma versão provisória; precisa ser revisada por um advogado.
- **Recuperação de senha** ("Esqueci minha senha"): precisa de envio de e-mail ou SMS.
- No celular, guardar o token em armazenamento seguro (`flutter_secure_storage`) em vez de `shared_preferences`.
- Trocar `EnsureCreated` por migrations do EF Core e definir o banco de produção (ex.: PostgreSQL).

## Logo e imagens

- Logo próprio (carro de frente em linhas azuis com um checklist no para-brisa + nome "Tok Mecânico" em Montserrat) e ícones: `app/assets/logo/` (SVG + PNG). Desenho original do projeto.
- Mascote: `app/assets/mascote/mecanico.png` — caricatura do fundador como mecânico, gerada por IA a partir do rosto dele (fundo removido). Imagem própria do projeto.
