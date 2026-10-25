# fix(security,time-clock,navigation): secure password recovery, retain work logs and reuse sessions

> Rascunho local para um único Pull Request de `fix/security-timeclock-navigation` para `main`. A publicação e o fechamento automático das issues ficam condicionados à validação dos requisitos pendentes, especialmente PostgreSQL READ COMMITTED e migração em uma instância PostgreSQL real. Nenhum `Closes` é usado enquanto isso.

## Summary

Protege a recuperação de senha contra alteração de credenciais apenas com e-mail e enumeração de contas; preserva WorkLogs nas exclusões, reconcilia alterações manuais, serializa batidas do mesmo funcionário e reutiliza com segurança a sessão entre telas sem fazer `/auth/me` a cada navegação.

## What Changed

- **#72:** `POST /auth/reset-password` inicia recuperação sem alterar credenciais; `POST /auth/reset-password/confirm` exige token opaco seguro, persistido apenas como representação criptográfica, com expiração e uso único. Solicitações equivalentes retornam o mesmo status e corpo; limites de tentativas persistidos no banco. A conclusão altera senha e revoga sessões de forma atômica, com envio de link pela infraestrutura Brevo e formulário Flutter dedicado.
- **#70:** modelo e migração preservam WorkLogs após exclusões de funcionários e batidas. Vínculos para fontes operacionais admitem `NULL` e usam `ON DELETE SET NULL`; snapshots históricos e referência estável do funcionário são mantidos. Deleções destacam os vínculos em transação e os relatórios históricos consultam o snapshot quando necessário.
- **#77:** `projectId` omitido mantém o vínculo; `projectId: null` o remove intencionalmente. Edições manuais reconciliam duração e intervalos dos WorkLogs vinculados, sem reatribuir silenciosamente projetos/tarefas históricos. Sequências incompatíveis rejeitam alterações antes de commit.
- **#81:** escritores automáticos e administrativos adquirem lock transacional por Employee, e deleção de empregado usa o mesmo protocolo. A decisão da transição consulta somente o último registro com `ORDER BY timestamp DESC, id DESC LIMIT 1` apoiado por índice composto. Testes verificam SQL limitado e plano de índice; o teste adversarial PostgreSQL foi preparado para banco exclusivo em READ COMMITTED.
- **#83:** o Router preserva a sessão autenticada entre rotas, deep links e navegação Back/Forward. O contexto de `auth/me` é cacheado por token, incluindo a requisição concorrente compartilhada. Uma revalidação de servidor é disparada no retorno ao aplicativo, a cada 5 minutos, na expiração, e por rejeição 401/403; falhas de rede ocultam conteúdo protegido até nova verificação sem descartar a sessão. Respostas antigas não derrubam novo login.

## Why

As cinco issues descrevem problemas compartilhados de segurança, concorrência e consistência. A integração aplica contratos comuns onde existem vínculos entre Employee, Punch e WorkLog, preservando a estrutura e os endpoints existentes fora dos fluxos de recuperação de senha e o contrato explícito de limpeza de projeto.

## How to Test

1. Requisitar recuperação para conta existente, inexistente, inativa e acima do limite, comparando resposta pública; conferir que senha/sessões só mudam após confirmação do token.
2. Validar tokens expirados, reutilizados, substituídos, inválidos e confirmações simultâneas, além de falha de entrega Brevo.
3. Com SQLite `foreign_keys=ON`, excluir batida e funcionário com WorkLogs; validar snapshots preservados, FK-check sem erro, migração legada idempotente e rollback de edições incompatíveis.
4. Em **PostgreSQL real, banco isolado**, ativar isolamento `READ COMMITTED`, executar simultaneamente transições de check-in e edições/exclusões administrativas, validar uma única transição válida e integridade transacional.
5. Executar cenário com histórico grande; conferir consultas com `LIMIT 1`, plano de índice e equivalência funcional da sequência.
6. Abrir e navegar workspace autenticado; testar URL, Voltar/Avançar, refresh, recuperação via deep link, falha de rede e revogação; contabilizar chamadas a `/auth/me`.
7. Executar `python scripts/polis_tests.py`, `dart analyze lib test` em `frontend`, `flutter build web --release` e `node test/browser/first_paint_smoke.mjs` após o build. Executar gates POLIS correspondentes pela política commitada.

## Expected Behavior

Um e-mail nunca basta para trocar credenciais. WorkLogs conservam histórico auditável e dados coerentes com a sequência operacional após deleções e edições permitidas. Requisições de ponto concorrentes do mesmo funcionário não derivam transições incompatíveis da mesma condição inicial. Navegação interna reutiliza a sessão validada, mas respostas de revogação e falhas de conectividade têm tratamento de segurança previsível.

## Screenshots / Evidence

Os testes RED demonstraram erro de FK em exclusões SQLite e `/auth/me` redundante ao navegar (2 chamadas após 1 troca; expectativa 1). A suíte de navegação e cache passou após correção (12 testes direcionados). Registros completos de execução integrada devem ser acrescentados antes de publicar.

## Risks / Impact

- Migração de FKs em WorkLogs requer backup antes do deploy e etapa explícita onde o bootstrap de produção está desativado. Testes PostgreSQL requerem banco exclusivo e rollback validado.
- Instalações atrás de proxies precisam encaminhar e confiar corretamente o IP do cliente para que o limite por IP corresponda ao solicitante real. A eficácia contra abuso distribuído depende também do perímetro operacional.
- Configure `TOUCHIN_PASSWORD_RESET_URL` para o domínio real HTTPS e Brevo para entrega da recuperação. Na estratégia de hash do Flutter Web, a URL de confirmação é `https://dominio/#/reset-password?token=...`.
- A janela máxima de revalidação periódica de sessão é 5 minutos, reduzida por requisições com resposta 401/403, retorno à aplicação e expiração local. Confirmação de revogação depende de `/auth/me` acessível; rede indisponível bloqueia temporariamente a visualização do workspace.
- Ausência de uma instância PostgreSQL real impede atestar a concorrência de #81 e a migração de #70 para esse banco; não declarar essas condições aprovadas sem executá-las.

## Checklist

- [ ] Changes were tested locally (validação integrada completa pendente)
- [ ] Existing behavior was not unintentionally affected (suite e revisão completa pendentes)
- [x] Relevant tests were added or updated
- [x] Documentation was updated if needed
- [ ] No unrelated changes are included (revisão final pendente)

## Additional Notes

Rastreabilidade e decisões de produto documentadas em `docs/security-timeclock-navigation-traceability.md`. Esta descrição é um único PR local proposto para `main`; não faz push, abertura de PR, merge ou deploy. Adicionar somente os `Closes #72`, `Closes #70`, `Closes #77`, `Closes #81`, `Closes #83` cujas validações obrigatórias e critérios de aceite estejam comprovados antes da publicação.
