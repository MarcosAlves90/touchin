# Desenvolvimento

## Ferramentas

- Python 3.12 é a versão usada pelo CI do backend. Para os gates locais, a policy invoca o comando `python`.
- Flutter pelo canal stable e Dart compatível com o intervalo em `frontend/pubspec.yaml`.
- Git para obter o repositório.
- Go 1.23 e Node.js 24 são usados pelo CI para instalar/executar POLIS e smoke tests do navegador.

## Preparar o backend

Para desenvolver e inspecionar a interface sem backend, conta ou `.env`,
use a [prévia de desenvolvimento offline](DEVELOPER_PREVIEW.md). Ela é opt-in
no build, não um efeito automático de debug.

Na raiz do repositório:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
cp .env.example .env
# Edite .env: use dois segredos locais distintos e defina sua senha de seed.
python -m uvicorn app.main:app --reload --port 8071
```

No PowerShell, execute a sequência completa a partir da raiz do repositório:

```powershell
Set-Location backend
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
# Edite .env: use dois segredos locais distintos e defina sua senha de seed.
python -m uvicorn app.main:app --reload --port 8071
```

Copie `.env.example` somente no primeiro setup; não substitua um `.env` existente. Com o seed ligado, a API inicializa o schema e preenche os [dados de demonstração](../backend/app/seed.py) faltantes. Contas novas de seed usam a senha local escolhida em `TOUCHIN_SEED_ADMIN_PASSWORD`; mudar essa variável não redefine senhas existentes. A API responde em `http://127.0.0.1:8071`; health check: `/api/v1/health`; documentação interativa: `/docs`.

## Preparar o frontend

Em outro terminal, na raiz:

```bash
cd frontend
flutter pub get
flutter run -d web-server --web-port 8080
```

O comando acima abre o aplicativo normal, mesmo quando o Flutter compila
em debug. Para abrir a [prévia offline](DEVELOPER_PREVIEW.md), acrescente
`--dart-define=TOUCHIN_FRONTEND_DEV_MODE=true`. Essa opção não muda a URL da API.

O endereço local padrão do frontend é `http://localhost:8071/api/v1`, definido em `lib/core/config/app_config.dart`. Por isso, o comando local do backend acima usa a porta `8071`. Para usar outra URL, passe `--dart-define=API_BASE_URL=https://host/api/v1` ao comando de build/run. Abra `http://localhost:8080`. O backend admite origens locais de `localhost` e `127.0.0.1` pela [política CORS](../backend/app/main.py); acrescente outras origens com `TOUCHIN_ALLOWED_ORIGINS`.

## Testes e análise

Execute os testes focados dentro dos respectivos diretórios:

```bash
(cd backend && python -m pytest -q)
(cd frontend && flutter test test/developer_preview_entry_test.dart)
(cd frontend && flutter test --dart-define=TOUCHIN_FRONTEND_DEV_MODE=true --exclude-tags canonical-golden)
(cd frontend && dart analyze lib test)
```

No PowerShell, execute os comandos nos respectivos diretórios, sem o wrapper `(cd ... && ...)`. O teste isolado de entrada verifica o padrão sem o flag; a segunda execução cobre a prévia. Os [goldens canônicos](../frontend/test/goldens/rounded_workspace_navigation/README.md) comparam pixels no Ubuntu com Flutter 3.47.2. Para cobertura de concorrência, use os bancos descartáveis do [job PostgreSQL](../.github/workflows/ci.yml); testes SQLite não substituem aquele job.

Para a validação de gates usada pelo repositório, instale a mesma versão do CI e execute a policy:

```bash
go install github.com/MarcosAlves90/polis/v6/cmd/polis@v6.12.0
polis doctor --repo .
polis plan --repo .
polis gates --repo . --gate test.complete --gate lint --gate build --gate smoke
```

O `.polis/policy.json` é a fonte dos gates locais: `test.complete`, `lint`, `build` e `smoke`. O smoke depende do build. O gate `test.complete` chama literalmente `python scripts/polis_tests.py`; em sistemas onde só existe `python3`, `polis doctor --repo .` aponta a ausência de `python`. Configure uma distribuição compatível com Python 3.12 que exponha esse comando antes de rodar os gates. Não há `package.json` na raiz; `npm run verify` não é o comando de validação deste projeto.

## CI no GitHub Actions

O [workflow CI](../.github/workflows/ci.yml) roda em pull requests, em pushes à `main` e manualmente. Pushes em branches de trabalho não criam uma segunda execução; um novo commit no mesmo PR cancela a execução mais antiga do PR. Pushes à `main` e execuções manuais não se cancelam entre si.

- **Ubuntu, em todos os eventos:** suítes de backend e Flutter com cobertura, concorrência em PostgreSQL, análise, build web, smoke no Chrome, histórico de navegação autenticada e comparação visual canônica.
- **Windows, nos PRs:** validação da policy POLIS, testes do adaptador de comandos, análise estática via POLIS e testes focados de navegação Flutter.
- **Windows, na `main` e em execução manual:** gates completos `test.complete`, `lint`, `build` e `smoke`. Para rodá-los antes do merge, abra **Actions → CI → Run workflow** e selecione a branch do PR. Regressões exclusivas de Windows fora dos testes focados podem só aparecer nessa execução completa.

## Referências

- [README](../README.md): visão geral e início rápido.
- [Backend](../backend/README.md): configuração e áreas da API.
- [Deploy](DEPLOYMENT.md): o que a configuração versionada cobre e o que depende do ambiente externo.
- [Contexto](../CONTEXT.md): resumo de arquitetura e convenções.
- [Contratos POLIS](contracts/): especificações versionadas de mudanças; não são documentação de operação.
- [Evidências de validação](validation/): provas de regressão e relatórios POLIS retidos por mudança.
