# Deploy

## Frontend Web no Vercel

O repositório versiona a configuração do frontend em `frontend/vercel.json` e o script `frontend/scripts/vercel-build.sh`. Para que os caminhos relativos dessa configuração funcionem, configure `frontend/` como root directory do projeto Vercel. A configuração versionada define:

- comando de build: `bash scripts/vercel-build.sh`;
- saída: `build/web`;
- rewrite para `/index.html` e cabeçalhos de browser, incluindo CSP e `Permissions-Policy`, que permite geolocalização à própria origem.

No ambiente de build do Vercel, `API_BASE_URL` é obrigatória. Informe a URL pública base da API incluindo `/api/v1`, sem acrescentar um recurso como `/audit-events`. O script transforma a variável em `--dart-define` do Flutter; portanto, uma alteração requer novo build/deploy do frontend. O backend deve aceitar a origem do site em `TOUCHIN_ALLOWED_ORIGINS`.

O frontend usa modo de produção por padrão, sem tela de prévia de
desenvolvimento. Somente `TOUCHIN_FRONTEND_DEV_MODE=true` no ambiente de
**build** ativa a prévia, inclusive em builds release do Vercel. Deixe essa
variável ausente em produção; se necessária, limite-a a um ambiente de teste.
O script converte a variável em `--dart-define`. Mudar o valor exige um novo
build e não altera a URL da API nem o `TOUCHIN_ENV` do backend.

O script usa o Flutter stable no diretório `FLUTTER_HOME` ou no cache padrão `~/.cache/flutter-sdk`. Se o diretório escolhido não contém `bin/flutter`, ele baixa o release stable atual do Flutter. O comportamento está definido em `frontend/scripts/vercel-build.sh`.

## Backend e ambientes

Este repositório não versiona configuração de um provedor de deploy do backend nem URLs de staging/produção. O comando da aplicação é `uvicorn app.main:app`; porta, processo, banco, secrets, domínio e health-check do serviço devem ser definidos conforme o provedor efetivamente escolhido. Não use a configuração local de `.env.example` em produção.

Ao configurar um ambiente real, verifique no código e no provedor:

- `TOUCHIN_ENV=production` explícito no backend, pois seu padrão é `development`; o flag do frontend não muda esse valor;
- `TOUCHIN_TOKEN_SECRET` e `TOUCHIN_ENCRYPTION_SECRET` como segredos distintos do ambiente;
- `TOUCHIN_DATABASE_URL` com driver PostgreSQL suportado (`postgresql+psycopg2`, `postgresql` ou `postgres`), se PostgreSQL for usado;
- `TOUCHIN_ALLOWED_ORIGINS` com a origem real do frontend;
- `TOUCHIN_ENFORCE_HTTPS` e os parâmetros de HTTPS/proxy do ambiente;
- `TOUCHIN_SEED_ON_STARTUP=false` para não inserir dados de demonstração; defina `TOUCHIN_BOOTSTRAP_DATABASE_ON_STARTUP` de acordo com a política de schema;
- para recuperação pública de senha, configure a [integração Brevo](../backend/README.md) e `TOUCHIN_PASSWORD_RESET_URL` com a URL HTTPS do frontend. No Flutter Web, a rota é `/#/reset-password`; não acrescente query nem token à variável.

### Schema e health check

Se o bootstrap estiver desligado, aplique a inicialização/atualização antes de servir tráfego. Com as dependências instaladas e as variáveis corretas, execute a partir de `backend/`:

```sh
python -c "from app.db import init_database; init_database()"
```

[`init_database()`](../backend/app/db.py) cria tabelas faltantes e chama o [upgrade de schema](../backend/app/database_schema.py), sem executar seed. Antes de atualizar um banco com dados, faça backup e ensaie o procedimento em uma cópia isolada.

`GET /api/v1/health` verifica que a API atende requisições (`{"status":"ok"}`); a rota não consulta o banco. A disponibilidade real de deploy, conectividade do banco, domínio, secrets e configurações de painel não é verificável apenas pelo repositório; confirme esses pontos no ambiente antes de anunciar um deploy funcional.
