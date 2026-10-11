# Score Report — TouchIn Flutter Web: eliminação do flash branco

> Data: 2026-10-11 | Escopo: diferenças locais em relação a `22cdf87` (cinco arquivos rastreados modificados e cinco novos) | Risco: **High** | Revisão: **go-score v1.1.0**

> **Registro histórico, anterior às correções subsequentes:** as notas e sugestões abaixo descrevem o diff no momento da revisão go-score. Desde então, o controlador passou a confirmar o hint visual somente após a escrita segura, a restaurar o último tema confirmado em falhas e a serializar escritas; o bootstrap passou a emitir avisos genéricos sem valores sensíveis; e o smoke foi refatorado e ampliado com screencast temporal amostrado e testes de armazenamento bloqueado. Esses achados não devem ser interpretados como pendências atuais. Os gates POLIS `test.complete`, `lint`, `build` e `smoke` passaram novamente na execução `6b3832427fe7af39c241a7d4a4114b5a752a36acc1db8746ca9d35b92b2304bb`. O contrato continua como draft v5 sem bloqueio histórico retroativo.

## Comprehension Summary

O HTML define fundos opacos antes do carregamento do Flutter e executa um pequeno script síncrono *inline* que lê uma indicação visual não sensível de `localStorage`. A CSP do Vercel autoriza esse script por SHA-256 específico. Quando a preferência criptografada é recuperada de `FlutterSecureStorage`, `ThemeModeController` corrige a indicação visual por meio de uma ponte JS disponível apenas na Web; a renderização e as rotas Flutter continuam sob o controle dos widgets existentes. O diff também introduz um runner portátil para as suítes backend/Flutter, gates POLIS de build e smoke, um teste de navegação por widgets e um teste Chrome/CDP que serve o build com CSP real, intercepta recursos, analisa pixels de screenshots, navega por controles de acessibilidade e reproduz uma preferência legada AES-GCM. O contrato POLIS documenta os requisitos e a restrição de migração, mas declara corretamente ser um **draft v5**, sem bloqueio retrospectivo de baseline.

## Tier and Segmentation

**High**: o caminho alterado lê/escreve uma indicação em armazenamento de navegador, integra preferência criptografada, usa WebCrypto no teste e implementa um servidor local de assets. Todas as sete dimensões foram examinadas integralmente. Como o diff inclui um teste de aproximadamente 605 linhas, a revisão foi segmentada:

- **A — Renderização e tema:** `frontend/web/index.html`, `frontend/vercel.json` e os três arquivos de `frontend/lib/core/theme/`.
- **B — Testes e navegação:** `frontend/test/widget_test.dart` e `frontend/test/browser/first_paint_smoke.mjs`.
- **C — POLIS e contrato:** `.polis/policy.json`, `scripts/polis_tests.py` e `docs/contracts/flutter-web-white-flash-fix-v1.polis.json`.

| Dimensão | A | B | C | Agregado (mínimo) |
|---|---:|---:|---:|---:|
| Correctness | 2 | 3 | 3 | **2** |
| Security | 3 | 3 | 3 | **3** |
| Maintainability | 3 | 2 | 3 | **2** |
| Testability | 2 | 2 | 2 | **2** |
| Performance | 3 | 3 | 3 | **3** |
| Design | 3 | 2 | 3 | **2** |
| Observability | 2 | 3 | 3 | **2** |

Os valores agregados são os **mínimos entre segmentos**; não são médias de implementação e testes.

## Scorecard

| Dimension | Score | Label |
|---|---:|---|
| Correctness | **2** | Minor defect |
| Security | **3** | Adequate |
| Maintainability | **2** | Minor defect |
| Testability | **2** | Minor defect |
| Performance | **3** | Adequate |
| Design | **2** | Minor defect |
| Observability | **2** | Minor defect |
| **Composite** | **2,3 / 4,0** | Média aritmética informativa |

**Dimensions scored:** Correctness 2, Security 3, Maintainability 2, Testability 2, Performance 3, Design 2, Observability 2. **Missing:** nenhuma.

## Evidence by Dimension

**Correctness — 2 (Minor defect; âncora: cenário excepcional pouco frequente).** Em `frontend/lib/core/theme/theme_mode_controller.dart:69-73`, `_mode = mode; theme_surface.syncBrowserThemeMode(mode); ... await _store.writeThemeMode(mode);` aplica e persiste a indicação visual **antes** de confirmar a preferência segura. O script em `frontend/web/index.html:66-73` grava a indicação em `localStorage`. Se a gravação segura falhar ou a página recarregar antes de concluí-la, o primeiro fundo do recarregamento pode divergir da preferência autoritativa e depois ser corrigido novamente. A reprodução isolada do bootstrap confirmou que o hint passa a `light` enquanto a preferência segura simulada ainda é `dark`. A recuperação normal, a migração legada e a navegação passaram nos testes anteriores.

**Security — 3 (Adequate; âncora: riscos previsíveis de entrada controlados).** `frontend/web/index.html:67` restringe o valor a `light`, `system` ou `dark`; `frontend/vercel.json:25-26` mantém `script-src 'self' 'wasm-unsafe-eval' 'sha256-3ky3QPcGiFUTfC2arM+y4GDA/enTo++2O4zTDOIF3Xo=' ...`, sem liberar scripts inline arbitrários. No teste, `frontend/test/browser/first_paint_smoke.mjs:107-110,129-132` confina o servidor a `127.0.0.1` e rejeita caminhos fora do diretório do build. O hint não contém dados de autenticação; a preferência criptografada continua no armazenamento utilizado pelo plugin.

**Maintainability — 2 (Minor defect; âncora: concentração excessiva de responsabilidades).** `frontend/test/browser/first_paint_smoke.mjs:387-600` concentra setup de Chrome, cenários de rede/tema, navegação, criptografia legada e teardown numa única função `smoke()` extensa. A estrutura de helpers CDP é reutilizável, mas a evolução e o diagnóstico de novos cenários exigirão percorrer muitos estados mutáveis (`release`, `disableInterception`, `cdp`). O restante da implementação é pequeno e coeso.

**Testability — 2 (Minor defect; âncora: cobertura real, porém temporalmente amostrada).** `frontend/test/browser/first_paint_smoke.mjs:289-296` inspeciona pixels reais de screenshots, mas `waitForFlutter` em `:372-380` espera `300 ms` após detectar o renderer e então faz uma captura; a navegação em `:523-547` usa capturas discretas. Isso **não demonstra ausência de todo flash de um único frame** entre amostras. A cobertura não inclui a falha de gravação segura descrita em Correctness. O teste é repetível e já exerce os cenários críticos, dentro dessas limitações.

**Performance — 3 (Adequate; âncora: custo limitado e caminho de primeira pintura mínimo).** `frontend/web/index.html:63-76` executa uma leitura curta de `localStorage` e atualiza um atributo de tema sem fetch adicional ou timers. Os ciclos de pixels de `frontend/test/browser/first_paint_smoke.mjs:271-286` são limitados a um framebuffer de `1050 × 760` no harness, fora do código de produção. Não há laços de custo variável sobre dados de usuário, consultas N+1 nem estruturas sem limite visíveis neste diff.

**Design — 2 (Minor defect; âncora: fronteiras de produção adequadas, harness pouco separado).** `frontend/lib/core/theme/theme_mode_controller.dart:4-5` seleciona uma implementação web de `theme_surface_sync` via import condicional, e `theme_surface_sync_stub.dart:1-3` isola plataformas não web. A fronteira é apropriada. Em contrapartida, `frontend/test/browser/first_paint_smoke.mjs:387-600` acopla orquestração de navegador e todos os cenários num fluxo sequencial longo, dificultando isolar uma única regressão quando um passo anterior falha.

**Observability — 2 (Minor defect; âncora: falha degradada sem sinal diagnóstico).** `frontend/web/index.html:69,72` usa `catch (_) {}` nas duas operações de armazenamento. O fallback escuro é seguro e intencional, mas a falha de acesso e a indisponibilidade de sincronização não deixam indicação diagnóstica, o que dificulta separar restrições do navegador de um erro de migração relatado. Em contraposição, `frontend/test/browser/first_paint_smoke.mjs:602-604` devolve erro explícito com stack, e `scripts/polis_tests.py:21-24` propaga o código de falha do processo.

## Verdict

**READY TO MERGE** — segundo os critérios **de qualidade do diff** do go-score: nenhuma nota 0 ou 1 e nenhum BLOCKER/WARNING de código demonstrado. Há sugestões de robustez abaixo. Esta classificação **não substitui** uma eventual exigência de contrato POLIS bloqueado ou evidência de entrega autenticada; o contrato atual é expressamente um draft pós-implementação.

## Findings

### BLOCKER

Nenhum defeito crítico ou vulnerabilidade demonstrados nos arquivos revisados.

### WARNING

Nenhum achado que satisfaça a classificação de nota 1.

### SUGGESTION

**[Correctness] [2/Minor defect] — SUGGESTION**

- **Observation:** `frontend/lib/core/theme/theme_mode_controller.dart:69-73`: `theme_surface.syncBrowserThemeMode(mode);` precede `await _store.writeThemeMode(mode);`; `frontend/web/index.html:69`: `localStorage.setItem(key, mode)`.
- **Impact:** recarregar durante uma escrita pendente, ou após ela falhar, pode iniciar com hint novo e preferência segura antiga, produzindo uma transição visual evitável.
- **Request:** acrescentar teste de escrita pendente/falha e definir reconciliação/rollback para a indicação visual, preservando a mudança imediata de tema na interface. Evitar criar um bloqueio de carregamento.

**[Testability] [2/Minor defect] — SUGGESTION**

- **Observation:** `frontend/test/browser/first_paint_smoke.mjs:372-380,523-547` espera e amostra screenshots em instantes específicos.
- **Impact:** um quadro branco muito curto entre essas capturas pode escapar à regressão automatizada, embora as capturas verificadas até aqui estejam corretas.
- **Request:** se a garantia for literalmente ausência de **qualquer** frame branco, complementar com tracing/filmstrip ou screencast contínuo de apresentação dos frames e teste de armazenamento inacessível. Não descrever a amostragem atual como prova exaustiva de cada frame.

**[Maintainability/Design] [2/Minor defect] — SUGGESTION**

- **Observation:** `frontend/test/browser/first_paint_smoke.mjs:387-600` mantém muitos cenários consecutivos dentro de `smoke()`.
- **Impact:** qualquer falha inicial bloqueia diagnósticos dos cenários seguintes e amplia o custo de modificar fluxos separados.
- **Request:** quando o smoke evoluir, extrair cenários em funções nomeadas que reutilizem o mesmo Chrome/CDP e o mesmo servidor, preservando o único processo de navegador e as verificações de pixels.

**[Observability] [2/Minor defect] — SUGGESTION**

- **Observation:** `frontend/web/index.html:69,72` suprime erros de armazenamento: `catch (_) {}`.
- **Impact:** é difícil diagnosticar uma preferência visual que não persiste em determinado navegador; isso não bloqueia a primeira pintura.
- **Request:** considerar diagnóstico discreto em desenvolvimento ou em testes de storage indisponível, sem registrar valores privados, sem lançar exceção do bootstrap e sem introduzir atraso.

### NIT

Nenhuma observação apenas estilística que justifique alteração.

## Positives

- O CSS crítico em `frontend/web/index.html:34-61` cobre `:root`, `body` e `flutter-view` com cores iguais às do tema Flutter, evitando depender da conclusão do download para definir o fundo.
- O bootstrap em `frontend/web/index.html:63-76` elimina a requisição extra de `theme_bootstrap.js`, e a CSP permite somente o SHA-256 do código embutido (`frontend/vercel.json:25-26`).
- O import condicional `frontend/lib/core/theme/theme_mode_controller.dart:4-5` preserva o comportamento das demais plataformas Flutter.
- O harness usa screenshots reais e amostras de pixels `frontend/test/browser/first_paint_smoke.mjs:252-318`, além de criar uma preferência **criptografada** no formato WebCrypto/AES-GCM `:550-583` para validar a migração verdadeira.
- O runner `scripts/polis_tests.py:17-24` usa `subprocess.run` com argv, propaga falhas e substitui o shell `bash -lc` antes presente na política.
- O contrato `docs/contracts/flutter-web-white-flash-fix-v1.polis.json:100-103,164-166` explicita tanto a ausência de baseline historicamente bloqueada quanto a migração excepcional sem hint anterior, sem inventar evidências.

## Calibration

- **Challenged Security (score 3):** o argumento mais forte para 2 é a superfície introduzida pelo servidor local e pela função JavaScript global. **Retained 3** porque o servidor escuta apenas em `127.0.0.1`, valida a contenção do caminho, o hint passa por enumeração restrita e a CSP contém hash específico; não foi encontrada passagem de input externo a um sink sensível.
- **Challenged Performance (score 3):** o argumento mais forte para 2 é a execução síncrona do bootstrap no `<head>` e a leitura de armazenamento no thread principal. **Retained 3** porque o trecho realiza operações constantes, sem rede, espera artificial, iteração crescente ou processamento pesado; não foi observado gargalo de produção.

Os segmentos que obtiveram 3 em outras dimensões foram reduzidos pelo mínimo dos segmentos A, B e C, conforme a rubrica. Nenhum resultado de testes isolado foi tratado como prova de ausência de todas as regressões.

## Open Questions

1. O processo de merge exige um **locked Change Contract** do POLIS? O draft schema v5 criado após o início do trabalho não pode ser retrospectivamente promovido a prova de `start`/`capture-red`. Se a política de integração exigir esse artefato, a aprovação processual ainda está pendente, apesar do veredito de código acima.
2. O fluxo de CI terá Chrome/Chromium instalado e `python3` disponível no PATH? A política configura `node test/browser/first_paint_smoke.mjs` e `python3 scripts/polis_tests.py` (`.polis/policy.json:9-12,61-70`). O smoke encontra executáveis comuns em macOS/Linux e aceita `TOUCHIN_CHROME`, mas não foi verificado num runner Windows.
3. Qual a expectativa formal para mudanças imediatas de tema com falha de persistência? O contrato define a preferência segura como autoritativa; não especifica rollback visual nesse erro.

## Scope Notes

- Referência Git: `22cdf87`; inspeção de cinco alterações rastreadas e cinco arquivos novos. Nenhum commit/PR/deploy foi criado. O próprio `SCORE_REPORT.md` é resultado desta revisão, portanto **não entrou no diff pontuado**.
- Há contrato de requisitos: `docs/contracts/flutter-web-white-flash-fix-v1.polis.json`, schema v5 draft. Não há lacuna de intenção declarada, mas há **lacuna de evidência formal de bloqueio da baseline**.
- Revisão estrutural por leitura de todas as linhas dos arquivos alterados. Checagem focalizada nesta revisão: `dart analyze lib/core/theme test/widget_test.dart` sem problemas, `node --check test/browser/first_paint_smoke.mjs` válido e `git diff --check` sem problemas. Em execução anterior, `polis doctor`, `polis plan` e os gates `test.complete`, `build`, `smoke` passaram com cópia externa idêntica da política editada. **Os gates não foram reexecutados depois da criação deste relatório.**
- A verificação Chrome amostra frames e recursos artificialmente suspensos; não constitui prova física de que nenhum navegador, rede ou estado intermediário possa produzir um frame branco. A primeira abertura de preferência legada clara sem hint pode transitar uma única vez de escuro para claro, conforme o contrato.
