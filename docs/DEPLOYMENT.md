# Deploy

## Frontend Web no Vercel

O repositório versiona a configuração do frontend em `frontend/vercel.json` e o script `frontend/scripts/vercel-build.sh`. Para que os caminhos relativos dessa configuração funcionem, configure `frontend/` como root directory do projeto Vercel. A configuração versionada define:

- comando de build: `bash scripts/vercel-build.sh`;
- saída: `build/web`;
- rewrite das rotas do app para `/index.html`.

No ambiente de build do Vercel, `API_BASE_URL` é obrigatória. Informe a URL pública base da API incluindo `/api/v1`, sem acrescentar um recurso como `/audit-events`. O script transforma a variável em `--dart-define` do Flutter; portanto, uma alteração requer novo build/deploy do frontend. O backend deve aceitar a origem do site em `TOUCHIN_ALLOWED_ORIGINS`.

O script usa o Flutter stable no diretório `FLUTTER_HOME` ou no cache padrão `~/.cache/flutter-sdk`. Se o diretório escolhido não contém `bin/flutter`, ele baixa o release stable atual do Flutter. O comportamento está definido em `frontend/scripts/vercel-build.sh`.

## Backend e ambientes

Este repositório não versiona configuração de um provedor de deploy do backend nem URLs de staging/produção. O comando da aplicação é `uvicorn app.main:app`; porta, processo, banco, secrets, domínio e health-check do serviço devem ser definidos conforme o provedor efetivamente escolhido. Não use a configuração local de `.env.example` em produção.

Ao configurar um ambiente real, verifique no código e no provedor:

- `TOUCHIN_TOKEN_SECRET` e `TOUCHIN_ENCRYPTION_SECRET` como secrets próprios do ambiente;
- `TOUCHIN_DATABASE_URL` com driver PostgreSQL suportado (`postgresql+psycopg2`, `postgresql` ou `postgres`), se PostgreSQL for usado;
- `TOUCHIN_ALLOWED_ORIGINS` com a origem real do frontend;
- `TOUCHIN_ENFORCE_HTTPS` e os parâmetros de HTTPS/proxy do ambiente;
- `TOUCHIN_SEED_ON_STARTUP` e `TOUCHIN_BOOTSTRAP_DATABASE_ON_STARTUP` de acordo com a política de dados e schema do serviço.

O health endpoint implementado é `GET /api/v1/health`. A disponibilidade real de deploy, conectividade do banco, domínio, secrets e configurações de painel não é verificável apenas pelo repositório; confirme esses pontos no ambiente antes de anunciar um deploy funcional.
