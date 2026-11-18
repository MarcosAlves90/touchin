# Validação móvel — issues #139–#143

Branch: `fix/mobile-bug-issues-139-143`
Base: `origin/main` em `2c4e6967717fa7fd45e912f20b63446179121eb3`

## Escopo

Correções para o badge de sincronização inicial (#139), busca redundante no Backlog móvel (#140), espaçamento do Kanban móvel (#141), área de rolagem do Audit Trail (#142) e largura dos skeletons de auditoria (#143). Os itens de lentidão #129 e #130 estão fora do escopo.

## Provas e artefatos POLIS

- Contrato bloqueado v6: `.polis/artifacts/contracts/mobile-bug-issues-139-143-v6.json` — SHA-256 `e0bf5aa4d36429be378ddf8546a38c9d62f19f8b101bc4124782106915ba5fe9`.
- Patch RED: `docs/validation/mobile-bug-issues-139-143/polis/red-regression.patch` — `polis capture-red` PASS, SHA-256 `54d73d762391251bea1c5285f22ca0b69332054d9e62daef4588b17047193d74`.
- Relatório de workspace: `docs/validation/mobile-bug-issues-139-143/polis/workspace-validation.json` — PASS; `test.complete`, `lint`, `build` e `smoke` passaram. Os demais gates estão `NOT_APPLICABLE` no perfil do projeto.

## Testes automatizados

- `flutter test --reporter expanded test/features/projects/presentation/project_kanban_page_test.dart test/admin_audit_page_test.dart test/admin_audit_export_test.dart` — passou.
- `python scripts/polis_tests.py` — 626 testes passaram; o runner exclui `canonical-golden` conforme a configuração do projeto.
- `flutter build web --release` — build concluído. O dry-run WASM registrou incompatibilidades conhecidas do `flutter_secure_storage_web` com `dart:html`/`dart:js_util`, mas o build web normal terminou com sucesso.
- Verificação de whitespace em código/testes e documentação, excluindo o patch unificado POLIS preservado byte a byte — passou.

Os quatro testes `canonical-golden` falham também em um worktree limpo de `origin/main` (mesmas capturas desktop/mobile em dark/light); não são regressões desta branch.

## Verificação visual local

Com a aplicação local em `localhost:8081`, API em `127.0.0.1:8071` e viewport móvel 390×844 no ego-browser:

- Kanban em loading: skeleton exibido sem o badge “Sincronizando”.
- Backlog: apenas a busca dentro dos filtros permanece; a tela não mostra as colunas do quadro.
- Kanban carregado: separação vertical entre as seções visível.
- Audit Trail: a lista rolou verticalmente por eventos consecutivos, mantendo a navegação superior visível.
- Audit Trail em loading: o contorno externo dos skeletons alinhou-se com os cards de evento carregados.

As capturas visuais não foram incluídas no repositório porque exibem dados do usuário de teste; a validação foi feita exclusivamente contra serviços locais.
