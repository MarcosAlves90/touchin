# Desenvolvimento

## Ferramentas

- Python 3.12 é a versão usada pelo CI do backend. Para os gates locais, a policy invoca o comando `python`.
- Flutter pelo canal stable e Dart compatível com o intervalo em `frontend/pubspec.yaml`.
- Git para obter o repositório.
- Go 1.23 e Node.js 24 são usados pelo CI para instalar/executar POLIS e smoke tests do navegador.

## Preparar o backend

Na raiz do repositório:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8071
```

No PowerShell, crie o ambiente com `py -3.12 -m venv .venv`, ative com `.venv\Scripts\Activate.ps1` e copie com `Copy-Item .env.example .env`. O arquivo de exemplo contém placeholders adequados apenas para desenvolvimento local. A API responde em `http://127.0.0.1:8071`; health check: `/api/v1/health`; documentação interativa: `/docs`.

## Preparar o frontend

Em outro terminal, na raiz:

```bash
cd frontend
flutter pub get
flutter run -d web-server --web-port 8080
```

O endereço local padrão do frontend é `http://localhost:8071/api/v1`, definido em `lib/core/config/app_config.dart`. Por isso, o comando local do backend acima usa a porta `8071`. Para usar outra URL, passe `--dart-define=API_BASE_URL=https://host/api/v1` ao comando de build/run. As origens locais padrão incluem a porta `8080`; para outras origens, confira `TOUCHIN_ALLOWED_ORIGINS` e a política CORS em `backend/app/main.py`.

## Testes e análise

Execute os testes focados dentro dos respectivos diretórios (em PowerShell, use `py -3.12 -m pytest -q` para o backend):

```bash
(cd backend && python -m pytest -q)
(cd frontend && flutter test)
(cd frontend && dart analyze lib test)
```

Para a validação de gates usada pelo repositório, instale a mesma versão do CI e execute a policy:

```bash
go install github.com/MarcosAlves90/polis/v6/cmd/polis@v6.12.0
polis doctor --repo .
polis plan --repo .
polis gates --repo . --gate test.complete --gate lint --gate build --gate smoke
```

O `.polis/policy.json` é a fonte dos gates locais: `test.complete`, `lint`, `build` e `smoke`. O smoke depende do build. O gate `test.complete` chama literalmente `python scripts/polis_tests.py`; em sistemas onde só existe `python3`, `polis doctor --repo .` aponta a ausência de `python`. Configure uma distribuição compatível com Python 3.12 que exponha esse comando antes de rodar os gates. O workflow `.github/workflows/ci.yml` configura Python 3.12 e também valida gates em Windows. Não há `package.json` na raiz; `npm run verify` não é o comando de validação deste projeto.

## Estrutura da documentação

- [README](../README.md): visão geral e início rápido.
- [Backend](../backend/README.md): configuração e áreas da API.
- [Deploy](DEPLOYMENT.md): o que a configuração versionada cobre e o que depende do ambiente externo.
- [Contexto](../CONTEXT.md): resumo de arquitetura e convenções.
- [Contratos POLIS](contracts/): especificações versionadas de mudanças; não são documentação de operação.
