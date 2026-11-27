# Backend TouchIn

API REST em FastAPI. O prefixo versionado é `/api/v1`; a documentação interativa do FastAPI fica em `/docs`, ReDoc em `/redoc` e o esquema OpenAPI em `/openapi.json`.

## Desenvolvimento local

Siga o [guia de desenvolvimento](../docs/DEVELOPMENT.md) para instalar dependências, preparar `.env`, iniciar a API e executar os testes. A aplicação usa SQLite por padrão e inicia na porta informada ao Uvicorn. O exemplo do repositório usa a porta `8071` para corresponder ao endereço padrão do frontend.

## Configuração

As configurações abaixo são lidas em `app/config.py`; os valores locais de exemplo estão em [.env.example](.env.example). Variáveis do processo prevalecem sobre `.env`.

| Variável | Uso e padrão |
| --- | --- |
| `TOUCHIN_APP_NAME` | Nome exibido pela API; padrão `TouchIn Backend`. |
| `TOUCHIN_ENV` | Ambiente do backend; padrão `development`. Use `production` explicitamente no deploy. |
| `TOUCHIN_DATABASE_URL` | URL SQLAlchemy; padrão `sqlite:///./touchin.db`. |
| `TOUCHIN_TIMEZONE` | Fuso padrão (`America/Sao_Paulo`), usado também pela empresa de seed. |
| `TOUCHIN_TOKEN_SECRET` | Segredo obrigatório para derivar o hash de lookup dos tokens. |
| `TOUCHIN_ENCRYPTION_SECRET` | Segredo obrigatório usado por `FieldCipher` para dados protegidos. |
| `TOUCHIN_TOKEN_TTL_HOURS` | TTL curto; padrão `12`. |
| `TOUCHIN_REMEMBER_ME_TTL_DAYS` | TTL de “manter conectado”; padrão `30`. |
| `TOUCHIN_ENFORCE_HTTPS` | Ativa a verificação HTTPS para tráfego não local; padrão `false`. |
| `TOUCHIN_BOOTSTRAP_DATABASE_ON_STARTUP` | Controla a inicialização/atualização de schema; por padrão ativo em `development` e `test`. |
| `TOUCHIN_SEED_ON_STARTUP` | Controla dados seed; por padrão ativo em `development` e `test`. |
| `TOUCHIN_SEED_ADMIN_PASSWORD` | Obrigatório quando seed está ativo; senha inicial de contas de seed novas. |
| `TOUCHIN_ALLOWED_ORIGINS` | Lista CSV de origens CORS; a API também admite origens HTTP(S) de `localhost` e `127.0.0.1` via regex. |
| `TOUCHIN_BREVO_API_KEY` | Chave opcional para integração de e-mail Brevo. |
| `TOUCHIN_BREVO_SENDER_EMAIL` | Endereço remetente da integração Brevo. |
| `TOUCHIN_BREVO_SENDER_NAME` | Nome remetente; padrão igual a `TOUCHIN_APP_NAME`. |
| `TOUCHIN_BREVO_WELCOME_ENABLED` | Ativa e-mails de boas-vindas; padrão `true`. |
| `TOUCHIN_PASSWORD_RESET_URL` | URL de recuperação: HTTPS, sem query, com fragmento `#/reset-password` opcional (adicionado pelo backend se faltar). HTTP só para `localhost`/`127.0.0.1`. Padrão: `http://localhost:8080/#/reset-password` fora de `production`; vazio em `production`. |
| `TOUCHIN_AUDIT_EXPORT_MAX_BYTES` | Limite do CSV de auditoria, inteiro positivo; padrão e teto de 1 MiB (1.048.576 bytes). |

`TOUCHIN_TOKEN_SECRET` e `TOUCHIN_ENCRYPTION_SECRET` são sempre exigidos na inicialização. Os valores de `.env.example` são placeholders para desenvolvimento, não segredos de produção.

`POST /api/v1/auth/reset-password` solicita o e-mail com resposta pública indistinguível e limites por IP e e-mail. `POST /api/v1/auth/reset-password/confirm` troca a senha mediante um token de uso único válido por 30 minutos e revoga sessões existentes na confirmação válida. O backend monta o link e envia pelo Brevo. Para a operação em produção, configurar HTTPS/Brevo e assegurar que o IP de origem utilizado nos limites seja fornecido por um proxy confiável. As migrações de `WorkLog` preservam referências históricas e devem ser ensaiadas com backup antes do deploy.

Para PostgreSQL, use `postgresql+psycopg2://`, `postgresql://` ou `postgres://`; as duas últimas formas são normalizadas para psycopg2. A dependência declarada é `psycopg2-binary`; o driver `postgresql+psycopg://` não é suportado. Confira [app/db.py](app/db.py) antes de alterar a URL usada por um ambiente.

`API_BASE_URL` e `TOUCHIN_FRONTEND_DEV_MODE` são configurações de build do frontend, não variáveis do backend. Veja [Deploy](../docs/DEPLOYMENT.md).

## Rotas

As rotas são registradas em `app/api/router.py`. Consulte `/docs` ou `/openapi.json` no servidor em execução para métodos, esquemas e permissões atuais.

| Área | Prefixo |
| --- | --- |
| Health | `GET /api/v1/health` |
| Autenticação | `/api/v1/auth` |
| Funcionários | `/api/v1/employees` |
| Projetos, tarefas, Kanban, relatórios e recomendações | `/api/v1/projects` |
| Ponto | `/api/v1/time-clock` |
| Auditoria | `/api/v1/audit-events` |
| Administração e configuração de IA | `/api/v1/admin` |

Use `Authorization: Bearer <token>` nas rotas protegidas. O OpenAPI descreve operações e schemas, mas não substitui a [matriz de permissões](app/authorization.py) nem as verificações de escopo em cada rota/serviço. Erros de domínio retornam `detail` e, quando definido, `code`; erros de validação e respostas específicas podem ter outro formato.

## Persistência e dados sensíveis

SQLite é o padrão local, com FKs habilitadas. PostgreSQL é aceito pelas formas de URL descritas acima. O bootstrap cria e atualiza o schema; ligar o seed também executa esse passo. Veja [como atualizar sem seed](../docs/DEPLOYMENT.md#schema-e-health-check). Sessões usam tokens bearer opacos e o backend consulta o hash do token; campos protegidos usam `FieldCipher`. Consulte o código de `app/security.py`, `app/crypto.py` e `app/domain/` para o comportamento vigente.

## Validação

O CI executa `pytest` no backend e aplica os gates POLIS descritos em [Desenvolvimento](../docs/DEVELOPMENT.md). O CI fixa Python 3.12; as restrições completas das bibliotecas estão em `requirements.txt`.
