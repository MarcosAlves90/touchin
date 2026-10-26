# Backend TouchIn

API REST em FastAPI. O prefixo versionado é `/api/v1`; a documentação interativa do FastAPI fica em `/docs` e o esquema OpenAPI em `/openapi.json`.

## Desenvolvimento local

Siga o [guia de desenvolvimento](../docs/DEVELOPMENT.md) para instalar dependências, preparar `.env`, iniciar a API e executar os testes. A aplicação usa SQLite por padrão e inicia na porta informada ao Uvicorn. O exemplo do repositório usa a porta `8071` para corresponder ao endereço padrão do frontend.

## Configuração

As configurações abaixo são lidas em `app/config.py`; os valores locais de exemplo estão em `.env.example`.

| Variável | Uso e padrão |
| --- | --- |
| `TOUCHIN_APP_NAME` | Nome exibido pela API; padrão `TouchIn Backend`. |
| `TOUCHIN_ENV` | Ambiente; padrão `development`. |
| `TOUCHIN_DATABASE_URL` | URL SQLAlchemy; padrão `sqlite:///./touchin.db`. |
| `TOUCHIN_TIMEZONE` | Fuso empresarial; padrão `America/Sao_Paulo`. |
| `TOUCHIN_TOKEN_SECRET` | Segredo obrigatório para derivar o hash de lookup dos tokens. |
| `TOUCHIN_ENCRYPTION_SECRET` | Segredo obrigatório usado por `FieldCipher` para dados protegidos. |
| `TOUCHIN_TOKEN_TTL_HOURS` | TTL curto; padrão `12`. |
| `TOUCHIN_REMEMBER_ME_TTL_DAYS` | TTL de “manter conectado”; padrão `30`. |
| `TOUCHIN_ENFORCE_HTTPS` | Ativa a verificação HTTPS para tráfego não local; padrão `false`. |
| `TOUCHIN_BOOTSTRAP_DATABASE_ON_STARTUP` | Controla a inicialização/atualização de schema; por padrão ativo em `development` e `test`. |
| `TOUCHIN_SEED_ON_STARTUP` | Controla dados seed; por padrão ativo em `development` e `test`. |
| `TOUCHIN_SEED_ADMIN_PASSWORD` | Obrigatório quando seed está ativo; senha dos usuários seed locais. |
| `TOUCHIN_ALLOWED_ORIGINS` | Lista CSV de origens CORS; o padrão contém origens localhost. |
| `TOUCHIN_BREVO_API_KEY` | Chave opcional para integração de e-mail Brevo. |
| `TOUCHIN_BREVO_SENDER_EMAIL` | Endereço remetente da integração Brevo. |
| `TOUCHIN_BREVO_SENDER_NAME` | Nome remetente; padrão igual a `TOUCHIN_APP_NAME`. |
| `TOUCHIN_BREVO_WELCOME_ENABLED` | Ativa e-mails de boas-vindas; padrão `true`. |

`TOUCHIN_TOKEN_SECRET` e `TOUCHIN_ENCRYPTION_SECRET` são sempre exigidos na inicialização. Os valores de `.env.example` são placeholders para desenvolvimento, não segredos de produção.

Para PostgreSQL, use `postgresql+psycopg2://`, `postgresql://` ou `postgres://`; as duas últimas formas são normalizadas para psycopg2. A dependência declarada é `psycopg2-binary`; o driver `postgresql+psycopg://` não é suportado. Confira `backend/app/db.py` antes de alterar a URL usada por um ambiente.

`API_BASE_URL` é uma configuração de build do frontend, não uma variável do backend. Veja [Deploy](../docs/DEPLOYMENT.md).

## Rotas

As rotas são registradas em `app/api/router.py`. Consulte `/docs` ou `/openapi.json` no servidor em execução para métodos, esquemas e permissões atuais.

| Área | Prefixo |
| --- | --- |
| Health | `GET /api/v1/health` |
| Autenticação | `/api/v1/auth` |
| Funcionários | `/api/v1/employees` |
| Projetos, tarefas, Kanban e relatórios | `/api/v1/projects` |
| Ponto | `/api/v1/time-clock` |
| Auditoria | `/api/v1/audit-events` |
| Administração | `/api/v1/admin` |

Use `Authorization: Bearer <token>` nas rotas que exigem autenticação; a especificação interativa informa os requisitos de cada operação. As regras de autorização ficam em `app/authorization.py` e nas rotas/serviços correspondentes.

## Persistência e dados sensíveis

SQLite é o padrão local. PostgreSQL é aceito pelas formas de URL descritas acima. Sessões usam tokens bearer opacos e o backend consulta o hash do token; campos protegidos usam `FieldCipher`. Consulte o código de `app/security.py`, `app/crypto.py` e `app/domain/` para o comportamento vigente.

## Validação

O CI executa `pytest` no backend e aplica os gates POLIS descritos em [Desenvolvimento](../docs/DEVELOPMENT.md). O CI fixa Python 3.12; as restrições completas das bibliotecas estão em `requirements.txt`.
