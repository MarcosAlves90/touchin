# fix(security,time-clock,navigation): secure password recovery, retain work logs and reuse sessions

> Rascunho local para um único Pull Request de `fix/security-timeclock-navigation` para `main`. Implementação e validação integrada foram concluídas em ambiente local, incluindo PostgreSQL 18.3 sob `READ COMMITTED`. Publicação depende de autorização; configuração real de e-mail, proxy e migração de produção continua sendo pré-requisito de implantação.

## Summary

Protege a recuperação de senha contra alteração de credenciais apenas com e-mail e enumeração de contas; preserva WorkLogs nas exclusões, reconcilia alterações manuais, serializa batidas do mesmo funcionário e reutiliza com segurança a sessão entre telas sem fazer `/auth/me` a cada navegação.

## What Changed

- **#72:** `POST /auth/reset-password` inicia recuperação sem alterar credenciais; `POST /auth/reset-password/confirm` exige token opaco seguro, persistido apenas como representação criptográfica, com expiração e uso único. Solicitações equivalentes retornam o mesmo status e corpo; limites de tentativas persistidos no banco. A conclusão altera senha e revoga sessões de forma atômica, com envio de link pela infraestrutura Brevo e formulário Flutter dedicado.
- **#70:** modelo e migração preservam WorkLogs após exclusões de funcionários e batidas. Vínculos para fontes operacionais admitem `NULL` e usam `ON DELETE SET NULL`; snapshots históricos e referência estável do funcionário são mantidos. Deleções destacam os vínculos em transação e os relatórios históricos consultam o snapshot quando necessário.
- **#77:** `projectId` omitido mantém o vínculo; `projectId: null` o remove intencionalmente. Edições manuais reconciliam duração e intervalos dos WorkLogs vinculados, sem reatribuir silenciosamente projetos/tarefas históricos. Sequências incompatíveis rejeitam alterações antes de commit.
- **#81:** escritores automáticos e administrativos adquirem lock transacional por Employee, e deleção de empregado usa o mesmo protocolo. A decisão da transição consulta somente o último registro com `ORDER BY timestamp DESC, id DESC LIMIT 1` apoiado por índice composto. Testes reais em PostgreSQL READ COMMITTED verificam a serialização, a espera de lock administrativa e plano de índice com 5.000 eventos.
- **#83:** o Router preserva a sessão autenticada entre rotas, deep links e navegação Back/Forward. O contexto de `auth/me` é cacheado por token, incluindo a requisição concorrente compartilhada. Uma revalidação de servidor é disparada no retorno ao aplicativo, a cada 5 minutos, na expiração, e por rejeição 401/403; falhas de rede ocultam conteúdo protegido até nova verificação sem descartar a sessão. Respostas antigas não derrubam novo login.

## Why

As cinco issues descrevem problemas compartilhados de segurança, concorrência e consistência. A integração aplica contratos comuns onde existem vínculos entre Employee, Punch e WorkLog, preservando a estrutura e os endpoints existentes fora dos fluxos de recuperação de senha e o contrato explícito de limpeza de projeto.

## How to Test

1. Requisitar recuperação para conta existente, inexistente, inativa e acima do limite, comparando resposta pública; conferir que senha/sessões só mudam após confirmação do token.
2. Validar tokens expirados, reutilizados, substituídos, inválidos e confirmações simultâneas, além de falha de entrega Brevo.
3. Com SQLite `foreign_keys=ON`, excluir batida e funcionário com WorkLogs; validar snapshots preservados, FK-check sem erro, migração legada idempotente e rollback de edições incompatíveis.
4. Em **PostgreSQL real, banco isolado**, ativar isolamento `READ COMMITTED`, executar simultaneamente transições de check-in, pedidos/confirmações de reset, disputa com escritor administrativo e integridade de exclusões e migração idempotente.
5. Executar cenário com histórico grande; conferir consultas com `LIMIT 1`, plano de índice e equivalência funcional da sequência.
6. Abrir e navegar workspace autenticado; testar URL, Voltar/Avançar, refresh, recuperação via deep link, falha de rede e revogação; contabilizar chamadas a `/auth/me`.
7. Executar `python scripts/polis_tests.py`, `dart analyze lib test` em `frontend`, `flutter build web --release` e `node test/browser/first_paint_smoke.mjs` após o build. Executar gates POLIS correspondentes pela política commitada.

## Expected Behavior

Um e-mail nunca basta para trocar credenciais. WorkLogs conservam histórico auditável e dados coerentes com a sequência operacional após deleções e edições permitidas. Requisições de ponto concorrentes do mesmo funcionário não derivam transições incompatíveis da mesma condição inicial. Navegação interna reutiliza a sessão validada, mas respostas de revogação e falhas de conectividade têm tratamento de segurança previsível.

## Screenshots / Evidence

Os testes RED demonstraram erro de FK em exclusões SQLite e `/auth/me` redundante ao navegar (2 chamadas após 1 troca; expectativa 1). Testes dirigidos de navegação/cache passaram após a correção. Os gates POLIS commitados passaram na execução `dbc1f5ca71c779db8cce9fa5d06f9f1ad42bdf9361fb266be3833df787a84157` (estado anterior à extensão PostgreSQL): `test.complete`, `lint`, `build` e `smoke`.

**PostgreSQL real:** PostgreSQL 18.3 (Ubuntu/WSL, usuário não privilegiado, instância isolada `touchin_time_clock_test_20261025`, porta local 55433, isolamento `READ COMMITTED`). Com `TOUCHIN_TIME_CLOCK_PG_URL` apontando para o banco isolado, `python -B -m pytest -q -vv tests/test_time_clock_integrity.py -k postgres`: **8 passed, 8 deselected (35,77 s)**. Abrange duas batidas concorrentes (apenas uma nova aceita), WorkLogs retidos na exclusão, migração legado PostgreSQL com dupla execução, duas confirmações concorrentes de token (uma aceita), bloqueio administrativo pela linha Employee, plano de índice com 5.000 eventos e `LIMIT 1`, rollback de edição manual inválida e emissão concorrente de tokens (um único token ativo). Testes adicionais usam SQLite com FKs ativas. O run POLIS do commit final fica identificado no relatório de entrega para não alterar fontes após os gates.

## Risks / Impact

- Migração de FKs em WorkLogs requer backup antes do deploy e etapa explícita onde o bootstrap de produção está desativado. A migração foi validada em instância PostgreSQL isolada com dados de teste legados; resta ensaio com cópia representativa dos dados reais antes da implantação.
- Instalações atrás de proxies precisam encaminhar e confiar corretamente o IP do cliente para que o limite por IP corresponda ao solicitante real. A eficácia contra abuso distribuído depende também do perímetro operacional.
- Configure `TOUCHIN_PASSWORD_RESET_URL` para o domínio real HTTPS e Brevo para entrega da recuperação. Na estratégia de hash do Flutter Web, a URL de confirmação é `https://dominio/#/reset-password?token=...`.
- A janela máxima de revalidação periódica de sessão é 5 minutos, reduzida por requisições com resposta 401/403, retorno à aplicação e expiração local. Confirmação de revogação depende de `/auth/me` acessível; rede indisponível bloqueia temporariamente a visualização do workspace.
- A entrega real de e-mail pela Brevo não foi exercitada com credenciais de produção; a integração e as falhas de entrega foram verificadas por testes controlados. A habilitação do fluxo depende da configuração operacional.

## Checklist

- [x] Changes were tested locally
- [x] Existing behavior was not unintentionally affected (suites e contratos cobertos passaram; testes não garantem ausência de defeitos fora da cobertura)
- [x] Relevant tests were added or updated
- [x] Documentation was updated if needed
- [x] No unrelated changes are included

## Additional Notes

Rastreabilidade e decisões de produto documentadas em `docs/security-timeclock-navigation-traceability.md`. Esta descrição é um único PR local proposto para `main`; não faz push, abertura de PR, merge ou deploy. O fechamento automático corresponde às cinco correções implementadas e testadas:

Closes #72

Closes #70

Closes #77

Closes #81

Closes #83
