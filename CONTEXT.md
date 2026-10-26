# CONTEXT.md — TouchIn

- Última atualização: 2026-10-25
- Versão do documento: 1.2.3

---

## 1. Visão Geral do Projeto

TouchIn é uma aplicação web para registro de ponto e gestão de equipes, com frontend Flutter e backend FastAPI.

- Capacidades: autenticação, jornada/ponto, funcionários, projetos, tarefas, Kanban e funções administrativas.
- [Frontend](./frontend), [backend](./backend), [documentação](./docs) e [início rápido](./README.md).

## 2. Stack Tecnológica

| Tecnologia | Referência versionada | Papel |
|---|---|---|
| Flutter/Dart | Flutter stable no CI; intervalo Dart em `frontend/pubspec.yaml` | Frontend web |
| Python | 3.12 no CI; restrições em `backend/requirements.txt` | Backend e gates POLIS |
| FastAPI, SQLAlchemy, Pydantic | Restrições em `backend/requirements.txt` | API e persistência |
| SQLite | URL padrão em `backend/app/config.py` | Banco local |
| PostgreSQL/psycopg2 | Dependência `psycopg2-binary`; URL compatível descrita em `backend/app/db.py` | Banco alternativo |

As versões/ranges completos devem ser lidos nos manifests e no workflow de CI, não inferidos deste resumo.

## 3. Arquitetura

- O Flutter organiza a UI por áreas em `frontend/lib/features/` e mantém configuração, navegação, rede, armazenamento e tema em `frontend/lib/core/`.
- O backend registra rotas em `backend/app/api/`, com código relacionado em `domain/` e `services/`.
- `backend/app/config.py` centraliza configuração por ambiente. O banco padrão é SQLite; as formas de URL PostgreSQL suportadas estão em `backend/app/db.py`.
- O contrato versionado da API começa em `/api/v1`.

## 4. Estrutura de Pastas

```text
backend/app/       API, domínio, serviços e persistência
backend/tests/     testes do backend
frontend/lib/      app Flutter
frontend/test/     testes do frontend
docs/              relatórios e contratos POLIS versionados
.polis/            policy de validação do repositório
```

Consulte os diretórios atuais antes de assumir que este mapa enumera todos os módulos.

## 5. Convenções de Código

- Python: `snake_case` para funções/variáveis e `PascalCase` para classes.
- Dart: `lowerCamelCase` para membros e `UpperCamelCase` para tipos/widgets.
- O frontend usa `analysis_options.yaml`; o backend usa `pytest`.
- Arquivos gerados como `*.freezed.dart` devem ser regenerados pela ferramenta correspondente, não editados manualmente.
- O fluxo local de validação e os gates estão em [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) e `.polis/policy.json`.

## 6. Fluxos Críticos

- Login e operações protegidas usam bearer token opaco; a API mantém sessões rastreáveis e valida o token conforme o código de autenticação.
- O frontend consulta a API em `/api/v1`; endereço local e configuração web estão em `frontend/lib/core/config/app_config.dart` e [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md).
- O módulo de ponto expõe ações `checkIn`, `breakStart`, `breakEnd` e `checkOut`; a API e suas regras atuais são a fonte de verdade.
- Setup de build web e limites de deploy estão em [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md). O repositório não define URLs de produção.
- Recuperação pública de senha utiliza solicitação indistinguível, token com prazo de 30 minutos, confirmação de uso único e revogação transacional de sessões. O link é gerado pelo serviço Brevo conforme `TOUCHIN_PASSWORD_RESET_URL`.
- Os históricos `WorkLog` sobrevivem à exclusão de batidas e funcionários por referência histórica independente. Operações de ponto e edições administrativas usam as regras de serialização e integridade em `backend/app/services/time_clock.py`.
- O frontend reutiliza o contexto autenticado entre rotas e revalida o token ao voltar ao aplicativo, periodicamente e após rejeição autenticada, sem perder os contratos de skeletons de conteúdo introduzidos nas issues #112 e #121.

## 7. Decisões Arquiteturais

Este arquivo é um resumo, não um registro de ADR. Contratos de mudança aprovados ficam em [`docs/contracts/`](./docs/contracts/). Confira o contrato e o código atuais antes de tratar uma especificação histórica como comportamento presente.

## 8. Segurança

- O backend usa bearer tokens opacos; sessões guardam um hash de lookup do token.
- Senhas são verificadas com PBKDF2-HMAC-SHA256; parâmetros implementados estão em `backend/app/security.py`.
- `FieldCipher` protege campos selecionados e payloads JSON; a implementação está em `backend/app/crypto.py`.
- `TOUCHIN_TOKEN_SECRET` e `TOUCHIN_ENCRYPTION_SECRET` são obrigatórios. Use secrets por ambiente e não copie placeholders de `.env.example` para produção.
- Esse resumo não representa certificação ou avaliação de conformidade.

## 9. Ambientes

| Ambiente | Estado confirmado no repositório |
|---|---|
| Desenvolvimento local | `.env.example` usa SQLite. Os comandos atuais estão em `docs/DEVELOPMENT.md`. |
| CI | `.github/workflows/ci.yml` define Python 3.12, Flutter stable e os jobs de teste/gates. |
| Staging/produção | URLs e provedor do backend não estão definidos nos arquivos inspecionados; confirme no ambiente de deploy. |

## 10. Integrações Externas

O código de configuração prevê integração de e-mail Brevo por `TOUCHIN_BREVO_*`. Credenciais e remetentes reais pertencem à configuração segura de cada ambiente; não são documentados aqui.

## 11. Padrões de API

- Prefixo: `/api/v1`.
- Health público implementado: `GET /api/v1/health`.
- Áreas de rota: `/auth`, `/employees`, `/projects` (inclui tarefas, Kanban e relatórios), `/time-clock`, `/audit-events` e `/admin`.
- `/docs` e `/openapi.json` são expostos pelo FastAPI durante execução local.
- Métodos, schemas e autenticação por operação devem ser consultados no OpenAPI e nas rotas em `backend/app/api/routes/`.

## 12. Regras de Negócio

As regras de ponto, autorização, escopo empresarial e validação estão nas rotas, serviços, domínio e schemas do backend. Este resumo não substitui esses contratos; os tipos de ação de ponto seguem os valores camelCase listados acima.

## 13. Observações para IA

- Leia instruções do repositório e `.polis/policy.json` antes de alterar o projeto.
- Preserve dados sensíveis e nunca registre secrets reais em documentação, testes ou Git.
- Siga os comandos de `docs/DEVELOPMENT.md`; não presuma que `npm run verify` exista.
- Verifique manifests, CI e código antes de atualizar versões, variáveis ou caminhos neste arquivo.

## 14. Pendências Técnicas

Este documento não é a fonte de status do backlog. Issues e contratos devem ser consultados para confirmar pendências; esta auditoria não revalidou o backlog técnico completo.

## 15. Glossário

| Termo | Definição |
|---|---|
| Ponto | Registro de jornada de trabalho |
| Bearer token opaco | Token aleatório de sessão, validado pelo backend |
| PII | Informação pessoal identificável |
| `FieldCipher` | Componente de criptografia de campos em `backend/app/crypto.py` |
