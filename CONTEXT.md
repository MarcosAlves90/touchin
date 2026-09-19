# CONTEXT.md — TouchIn App

- Última atualização: 2026-05-25
- Versão do documento: 1.2.1
- Mantenedor: Time Platform

---

## 1. Visão Geral do Projeto

App de gerenciamento empresarial para registro de ponto eletrônico, controle de jornada e alocação de funcionários em projetos.

- **Público-alvo:** PMs, líderes de equipe e funcionários
- **Problema resolvido:** Centralizar ponto, jornada e alocação com privacidade de dados pessoais
- **Estado atual:** Frontend Flutter com tema global persistido, tela de configurações, módulo de auth reorganizado e painel de admin com widgets extraídos; backend com read models separados, sessão extraída, bootstrap dedicado e sem bus de eventos interno
- **Links:** [docs](./docs), [frontend](./frontend), [backend](./backend)

---

## 2. Stack Tecnológica

| Tecnologia | Versão | Papel |
|---|---:|---|
| Flutter | 3.x | Frontend mobile/web |
| Dart | >=3.0 | Linguagem do frontend |
| FastAPI | 0.115.x | API REST |
| SQLAlchemy | 2.0.x | ORM |
| SQLite | dev | Banco local |
| PostgreSQL | 15.x | Banco de produção/staging |
| Uvicorn | 0.32.x | Servidor ASGI |
| Cryptography | 44.x | Criptografia de PII |
| Pytest | 8.3.x | Testes do backend |
| Brevo API | — | E-mail transacional |

---

## 3. Arquitetura

- **Frontend:** Clean Architecture por feature, com módulos em `auth`, `admin`, `settings`, `shared` e `time_tracking`
- **Backend:** Monólito modular com FastAPI, rotas por domínio em `api/routes/`, comandos em `services/`, read models e regras compartilhadas em `domain/`, lifecycle em `bootstrap.py` e upgrade de schema em `database_schema.py`
- **Persistência:** SQLAlchemy declarativo com UUIDs string como chaves primárias
- **Criptografia:** PII armazenada como ciphertext + hash para lookup. AES-GCM via `cryptography`
- **Autenticação:** Bearer token aleatório com hash em `auth_sessions`. Não usa JWT nem refresh token dedicado
- **Tema global:** `ThemeModeController` no frontend controla claro, escuro e seguir sistema, com padrão escuro e persistência local
- **Notificações:** e-mails transacionais via Brevo para boas-vindas, reset de senha, alteração de senha e credenciais de funcionário

---

## 4. Estrutura de Pastas

```text
backend/
  app/
    api/
      router.py
      routes/
    domain/
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

frontend/
  lib/
    main.dart
    contracts/
    core/
      config/
      forms/
      network/
      storage/
      theme/
    features/
      admin/
        presentation/
          admin_employees_page.dart
          admin_employees_page_widgets.dart
      auth/
        presentation/
          auth_session_navigation.dart
          forgot_password_page.dart
          login_page.dart
          logout_navigation.dart
          must_change_password_page.dart
          register_page.dart
          widgets/
            auth_shell.dart
            auth_form_widgets.dart
      settings/
        presentation/
          settings_page.dart
      shared/
      time_tracking/
    theme/
  test/
```

---

## 5. Convenções de Código

- **Backend:** snake_case para funções/variáveis, PascalCase para classes
- **Frontend:** lowerCamelCase para funções/variáveis, PascalCase para widgets e classes
- **IDs:** UUID v4 string (`str(uuid4())`)
- **PII:** sufixo `_ciphertext` para dados criptografados e `_hash` para índices de lookup
- **Datas:** `DateTime(timezone=True)` no backend e datas com fuso explícito quando possível
- **Commits:** Conventional Commits (`feat`, `fix`, `chore`, `docs`, `test`)
- **Linter:** `analysis_options.yaml` no frontend; `pytest` e checks Python no backend
- **Tipos:** evitar `dynamic` no Dart e `Any` no Python, salvo necessidade real

---

## 6. Fluxos Críticos

### Autenticação
1. `POST /api/v1/auth/register-company` cria empresa, usuário inicial e sessão
2. `POST /api/v1/auth/login` valida e-mail e senha e cria `AuthSession`
3. `POST /api/v1/auth/reset-password` gera senha temporária e dispara e-mail em background
4. `POST /api/v1/auth/change-password` exige contexto autenticado e envia confirmação por e-mail
5. `GET /api/v1/auth/me` devolve o contexto autenticado
6. `POST /api/v1/auth/logout` revoga a sessão e limpa token + sessão local
7. O frontend armazena a sessão auth em `flutter_secure_storage`, revalida no startup e envia `Authorization: Bearer <token>`

### Criação de Funcionário
1. Admin cria ou edita funcionário em `/api/v1/employees`
2. Campos sensíveis são criptografados antes da persistência
3. O frontend usa validação e máscaras, mas o backend continua sendo a fonte de verdade
4. A criação dispara e-mail com credenciais temporárias em background
5. A listagem e o detalhe respeitam a empresa do contexto autenticado e o timezone da empresa

### Registro de Ponto
1. Funcionário registra entrada, pausa ou saída em `/api/v1/time-clock/me/punches`
2. O estado atual vem de `/api/v1/time-clock/me`
3. Time clock gerenciado usa rotas em `/api/v1/time-clock/employees/{employee_id}/punches?page=&limit=`
4. O timestamp vem do servidor
5. Metadados e payloads opcionais ficam criptografados
6. Regras de localização e dispositivo confiável são aplicadas quando habilitadas
7. O módulo de time clock exige vínculo com employee para acesso ao fluxo próprio do usuário
8. Os tipos de ponto expostos no contrato atual são `checkIn`, `checkOut`, `breakStart` e `breakEnd`

### Tema Global
1. O app inicia com `ThemeModeController`
2. O modo salvo é carregado do armazenamento seguro
3. O padrão quando não há preferência salva é `ThemeMode.dark`
4. A tela de configurações permite escolher `claro`, `escuro` ou `seguir sistema`
5. A preferência é persistida por `ThemePreferenceStore`
6. A escolha é aplicada globalmente sem reiniciar o app

---

## 7. Decisões Arquiteturais (ADR)

### ADR-001: Criptografia de PII em nível de aplicação

- **Data:** 2026-05-23
- **Contexto:** Dados pessoais não podem ficar em texto simples no banco
- **Decisão:** Criptografia simétrica AES-GCM via `cryptography`
- **Alternativas:** pgcrypto no banco, hashing apenas
- **Consequências:** Lookup por hash, overhead de descriptografia e necessidade de recriptografia em troca de chave

### ADR-002: Autenticação estateless com bearer token rastreável

- **Data:** 2026-05-23
- **Contexto:** Necessidade de revogar sessões individuais
- **Decisão:** Token aleatório com hash em `auth_sessions`
- **Alternativas:** JWT ou OAuth2 completo
- **Consequências:** Lookup em banco a cada request, mas revogação simples e controle de expiração

### ADR-003: UUID string como chave primária

- **Data:** 2026-05-23
- **Contexto:** Evitar IDs sequenciais expostos
- **Decisão:** UUID v4 em string
- **Alternativas:** Inteiro auto-incremento ou UUID binário
- **Consequências:** Índices maiores, mas compatibilidade alta entre ambientes

---

## 8. Segurança

- **Senhas:** PBKDF2-SHA256 com 310.000 iterações e salt de 16 bytes
- **Tokens:** `secrets.token_urlsafe(32)` com hash SHA-256 armazenado em `auth_sessions.token_hash`
- **PII:** AES-GCM com chave de 256 bits via `TOUCHIN_ENCRYPTION_SECRET`
- **Lookup:** campos sensíveis também recebem hash para busca e unicidade
- **CORS:** Configurável via `TOUCHIN_ALLOWED_ORIGINS`
- **HTTPS:** Middleware `https_guard` bloqueia tráfego não seguro quando ativado
- **Secrets:** `TOUCHIN_TOKEN_SECRET` e `TOUCHIN_ENCRYPTION_SECRET` são obrigatórios
- **RBAC:** `authorization.py` concentra permissões por papel e checagem de acesso
- **Seed:** `seed.py` tem builders pequenos e `seed_database` como entrada simples para testes e bootstrap
- **Frontend:** sessão auth fica no `flutter_secure_storage`, não em armazenamento comum

---

## 9. Ambientes

| Ambiente | URL | DB | Acesso | Deploy automático |
|---|---|---|---|---|
| dev | `http://localhost:8000` | SQLite (`./touchin.db`) | equipe | `uvicorn app.main:app --reload` |
| staging | TBD | PostgreSQL | QA | TBD |
| prod | TBD | PostgreSQL | usuários finais | TBD |

---

## 10. Integrações Externas

### Brevo

- **API Key:** `TOUCHIN_BREVO_API_KEY`
- **Remetente:** `TOUCHIN_BREVO_SENDER_EMAIL` e `TOUCHIN_BREVO_SENDER_NAME`
- **Uso:** e-mail de boas-vindas, reset de senha, confirmação de senha alterada e credenciais temporárias
- **Comportamento em falha:** registra log e não bloqueia o fluxo principal

---

## 11. Padrões de API

- **Prefixo:** `/api/v1`
- **Formato:** JSON
- **Autenticação:** `Authorization: Bearer <token>`
- **Erros:** `{"detail": "mensagem"}`
- **Principais rotas:**
  - `/auth/register-company`
  - `/auth/login`
  - `/auth/reset-password`
  - `/auth/change-password`
  - `/auth/me`
  - `/auth/logout`
  - `/employees`
  - `/employees/{employee_id}/projects`
  - `/projects`
  - `/time-clock/me`
  - `/time-clock/me/punches`
  - `/time-clock/employees/{employee_id}/punches`
  - `/admin`
  - `/health`

---

## 12. Regras de Negócio

- **Empresa:** CNPJ único por hash, consentimento obrigatório e timezone configurável
- **Funcionário:** e-mail único por empresa, status, modo de trabalho e nível de acesso definidos
- **Perfil vinculado:** algumas rotas exigem employee associado ao usuário autenticado
- **Projetos:** funcionários podem ser listados por projeto e alocados por empresa
- **Ponto:** tipos `clock_in`, `clock_out`, `break_start`, `break_end`
- **Projeto:** associação N:N entre empresas e funcionários via tabela de junção
- **Sessão:** `expires_at` e `revoked_at` controlam validade e logout
- **Seed:** admin padrão pode ser criado na inicialização quando o banco estiver vazio

---

## 13. Observações para IA

- **Arquivos gerados:** `*.freezed.dart` não devem ser editados manualmente
- **Frontend:** rodar `dart run build_runner build` após alterar `contracts/`
- **Tema global:** o modo atual fica em `ThemeModeController` e o padrão é escuro
- **Auth:** páginas de auth compartilham widgets comuns em `features/auth/presentation/widgets/`
- **Admin:** `admin_employees_page.dart` foi dividido em arquivo principal + widgets auxiliares; pontos e membros estão mais compactos e o seletor desktop evita quebra de texto
- **Theme store:** o valor salvo do tema passa por `ThemePreferenceStore` em `core/theme/theme_mode_controller.dart`
- **Docs:** manter este arquivo e o `README.md` alinhados ao estado atual do repositório
- **Segredos:** nunca commitar valores reais de secret
- **Testes:** rodar `pytest` no backend e `flutter test` no frontend antes de commitar mudanças funcionais

---

## 14. Pendências Técnicas (Tech Debt)

- [ ] Considerar tool de migrations para o banco
- [ ] Adicionar testes de integração para fluxos completos de auth e ponto
- [ ] Documentar melhor a tela de configurações e o comportamento de tema por dispositivo
- [ ] Revisar a estratégia de deploy para staging e produção

---

## 15. Glossário

| Termo | Definição |
|---|---|
| TouchIn | Nome do app |
| Punch | Registro de ponto |
| Company | Empresa cliente |
| Employee | Funcionário vinculado a uma empresa |
| Workspace | Área de trabalho do app com navegação e contexto |
| PII | Personally Identifiable Information |
| Ciphertext | Dado criptografado armazenado em banco |
| Hash | Valor derivado usado para lookup |
| Brevo | Plataforma de e-mail transacional |
| ThemeModeController | Controlador global do tema no frontend |
