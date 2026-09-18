# TouchIn Backend

API FastAPI + SQLAlchemy para autenticação empresarial, gestão de funcionários, projetos e controle de ponto.

## Visão Geral

- Base path: `/api/v1`
- Stack principal: FastAPI, SQLAlchemy, Pydantic, cryptography, pytest
- Autenticação: bearer token opaco, armazenado como hash no banco
- Banco padrão: SQLite em desenvolvimento; PostgreSQL via `TOUCHIN_DATABASE_URL`
- Documentação interativa: `http://127.0.0.1:8000/docs`

## Estrutura Atual

```text
backend/
  app/
    api/
      router.py
      routes/
    domain/
      auth_read.py
      auth_session.py
      employee_read.py
      project_read.py
      time_clock_read.py
    schemas/
    services/
    main.py
    models.py
    security.py
    crypto.py
    authorization.py
    bootstrap.py
    database_schema.py
    dependencies.py
    seed.py
    scripts/
  tests/
  .env.example
  requirements.txt
  pytest.ini
```

## Como Rodar

### 1. Criar o `.env`

```powershell
Copy-Item backend\.env.example backend\.env
```

### 2. Ajustar segredos obrigatórios

```env
TOUCHIN_TOKEN_SECRET=troque-este-token-secret
TOUCHIN_ENCRYPTION_SECRET=troque-este-encryption-secret
```

### 3. Instalar dependências

```powershell
cd backend
py -3 -m pip install -r requirements.txt
```

### 4. Subir a API

```powershell
py -3 -m uvicorn app.main:app --reload
```

### 5. Rodar testes

```powershell
py -3 -m pytest -q
```

## Configuração

Variáveis mais importantes:

- `TOUCHIN_DATABASE_URL`: URL SQLAlchemy. Exemplo: `sqlite:///./touchin.db`
- `TOUCHIN_TOKEN_SECRET`: segredo para tokens opacos
- `TOUCHIN_ENCRYPTION_SECRET`: segredo para criptografia de PII
- `TOUCHIN_ALLOWED_ORIGINS`: CSV de origens liberadas no CORS
- `TOUCHIN_ENFORCE_HTTPS`: exige HTTPS fora de localhost quando `true`
- `TOUCHIN_BOOTSTRAP_DATABASE_ON_STARTUP`: cria tabelas e faz upgrade legado na inicialização
- `TOUCHIN_SEED_ON_STARTUP`: cria seed de desenvolvimento quando `true`
- `TOUCHIN_SEED_ADMIN_PASSWORD`: senha usada pelos usuários seed
- `TOUCHIN_BREVO_API_KEY`: chave opcional da Brevo
- `TOUCHIN_BREVO_SENDER_EMAIL`: remetente das mensagens
- `TOUCHIN_BREVO_SENDER_NAME`: nome do remetente
- `TOUCHIN_BREVO_WELCOME_ENABLED`: habilita e-mails de boas-vindas

Em produção, mantenha `TOUCHIN_BOOTSTRAP_DATABASE_ON_STARTUP=false` quando o banco já tiver o schema provisionado. Isso evita trabalho extra no boot do Render.

## Seed de Desenvolvimento

Com `TOUCHIN_SEED_ON_STARTUP=true`, a inicialização cria uma empresa e usuários de apoio.

| Role | Email | Senha |
| --- | --- | --- |
| admin | `marina.costa@touchin.com` | `TOUCHIN_SEED_ADMIN_PASSWORD` |
| manager | `caio.martins@touchin.com` | `TOUCHIN_SEED_ADMIN_PASSWORD` |
| employee | `bianca.nogueira@touchin.com` | `TOUCHIN_SEED_ADMIN_PASSWORD` |
| employee | `joao.lima@touchin.com` | `TOUCHIN_SEED_ADMIN_PASSWORD` |
| super_admin | `super.admin@touchin.com` | `TOUCHIN_SEED_ADMIN_PASSWORD` |

`emp-03` também tem `user-account` vinculado, então mudanças de `accessRole` funcionam no front quando esse funcionário é editado.

## Autenticação

### Login

```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "marina.costa@touchin.com",
  "password": "TOUCHIN_SEED_ADMIN_PASSWORD",
  "keepConnected": true
}
```

Resposta inclui `accessToken`. Use o token em rotas protegidas:

```http
Authorization: Bearer <accessToken>
```

### Fluxo de sessão

- O token nunca é salvo em texto puro no banco.
- O banco guarda apenas `token_hash`.
- `POST /api/v1/auth/logout` revoga a sessão atual.
- `keepConnected=true` usa o TTL longo configurado em `TOUCHIN_REMEMBER_ME_TTL_DAYS`.
- `keepConnected=false` usa o TTL curto configurado em `TOUCHIN_TOKEN_TTL_HOURS`; o frontend ainda pode reaproveitar a sessão salva localmente até `expiresAt`, então isso não faz logout imediato.

### Rotas de auth

| Método | Rota | Acesso |
| --- | --- | --- |
| POST | `/api/v1/auth/register-company` | público |
| POST | `/api/v1/auth/login` | público |
| POST | `/api/v1/auth/reset-password` | público |
| POST | `/api/v1/auth/change-password` | autenticado |
| GET | `/api/v1/auth/me` | `auth.read_context` |
| POST | `/api/v1/auth/logout` | autenticado |

`register-company`, `reset-password` e `change-password` podem disparar e-mails via Brevo em background. Falha de e-mail não desfaz o fluxo principal.

## Permissões

As permissões ficam em `app/authorization.py`.

| Role | Permissões principais |
| --- | --- |
| employee | ler contexto de auth, ler e registrar o próprio ponto, ler projetos |
| manager | employee read/update, projects create/update/assign, time clock manage |
| admin | manager + employee create/delete, projects delete, company manage |
| super_admin | admin + acesso cross-company |

Regras gerais:

- As rotas comuns são escopadas por empresa.
- `admin.cross_company` exige `super_admin`.

## Arquitetura Atual

- `services/` fica com comandos e orquestração
- `domain/` guarda read models e helpers compartilhados
- `bootstrap.py` concentra o lifecycle da app
- `database_schema.py` concentra upgrade de schema legado
- `seed.py` usa builders pequenos e expõe `seed_database`
- `time-clock/me` e `time-clock/employees/{employeeId}/punches` aceitam paginação por `page` e `limit`

## Endpoints

### Health

| Método | Rota | Auth |
| --- | --- | --- |
| GET | `/api/v1/health` | não |

### Employees

| Método | Rota | Permissão |
| --- | --- | --- |
| GET | `/api/v1/employees` | `employees.read` |
| GET | `/api/v1/employees/{employeeId}` | `employees.read` |
| POST | `/api/v1/employees` | `employees.create` |
| PUT | `/api/v1/employees/{employeeId}` | `employees.update` |
| PATCH | `/api/v1/employees/{employeeId}` | `employees.update` |
| DELETE | `/api/v1/employees/{employeeId}` | `employees.delete` |
| GET | `/api/v1/employees/{employeeId}/projects` | `projects.read` |

Payload de criação/edição:

```json
{
  "name": "Renata Souza",
  "role": "Analista Financeira",
  "department": "Financeiro",
  "email": "renata.souza@touchin.com",
  "phone": "(11) 94444-6060",
  "unit": "Backoffice Centro",
  "expectedShiftStart": "08:00",
  "expectedShiftEnd": "17:00",
  "status": "active",
  "workMode": "hybrid",
  "roleLevel": "specialist",
  "requiresLocationOnPunch": false,
  "trustedDeviceRequired": true,
  "notes": "Observação interna."
}
```

### Projects

| Método | Rota | Permissão |
| --- | --- | --- |
| GET | `/api/v1/projects` | `projects.read` |
| POST | `/api/v1/projects` | `projects.create` |
| GET | `/api/v1/projects/{projectId}` | `projects.read` |
| PUT | `/api/v1/projects/{projectId}` | `projects.update` |
| PATCH | `/api/v1/projects/{projectId}` | `projects.update` |
| DELETE | `/api/v1/projects/{projectId}` | `projects.delete` |
| GET | `/api/v1/projects/{projectId}/members` | `projects.read` |
| POST | `/api/v1/projects/{projectId}/members` | `projects.assign` |
| DELETE | `/api/v1/projects/{projectId}/members/{employeeId}` | `projects.assign` |

`DELETE /projects/{projectId}` marca o projeto como `inactive` e não remove fisicamente.

Payload de projeto:

```json
{
  "name": "Implantação Cliente Sul",
  "description": "Projeto de operação assistida.",
  "status": "active"
}
```

### Time Clock

| Método | Rota | Permissão |
| --- | --- | --- |
| GET | `/api/v1/time-clock/me` | `time_clock.read` |
| POST | `/api/v1/time-clock/me/punches` | `time_clock.punch` |
| GET | `/api/v1/time-clock/employees/{employeeId}/punches` | `time_clock.manage` |
| POST | `/api/v1/time-clock/employees/{employeeId}/punches` | `time_clock.manage` |
| PUT | `/api/v1/time-clock/employees/{employeeId}/punches/{punchId}` | `time_clock.manage` |
| PATCH | `/api/v1/time-clock/employees/{employeeId}/punches/{punchId}` | `time_clock.manage` |
| DELETE | `/api/v1/time-clock/employees/{employeeId}/punches/{punchId}` | `time_clock.manage` |

Transições automáticas permitidas no ponto próprio:

- `checkedOut` -> `checkIn`
- `working` -> `breakStart` ou `checkOut`
- `onBreak` -> `breakEnd` ou `checkOut`

Se o funcionário tiver `requiresLocationOnPunch=true`, a requisição precisa enviar `location`.

Payload de ponto próprio:

```json
{
  "type": "checkIn",
  "projectId": null,
  "location": {
    "latitude": -23.5632,
    "longitude": -46.6545,
    "accuracyMeters": 12,
    "capturedAt": "2026-04-25T16:30:00-03:00"
  }
}
```

Payload de ajuste gerencial:

```json
{
  "type": "checkIn",
  "timestamp": "2026-05-20T09:00:00-03:00",
  "detail": "Ajuste manual aprovado pelo gestor.",
  "projectId": null,
  "location": null
}
```

### Admin

| Método | Rota | Permissão |
| --- | --- | --- |
| GET | `/api/v1/admin/companies` | `admin.cross_company` |

## Privacidade e Segurança

PII protegida:

- nome, e-mail, telefone, CNPJ, unidade, cargo, departamento e notas são criptografados em repouso
- e-mail e CNPJ também recebem HMAC determinístico para lookup sem texto puro
- payload de localização do ponto é criptografado
- tokens são opacos e o banco guarda apenas o hash

Regras operacionais:

- não logar payload sensível
- usar HTTPS fora de localhost em ambientes reais
- manter `TOUCHIN_TOKEN_SECRET` e `TOUCHIN_ENCRYPTION_SECRET` definidos
