# Auditoria de acessibilidade — issue #64

Data: 18 de outubro de 2026.

Referência: [issue #64](https://github.com/MarcosAlves90/touchin/issues/64).
Critérios de referência: [WCAG 2.2](https://www.w3.org/TR/WCAG22/),
especialmente 1.3.1 (informação e relações), 1.4.10 (refluxo),
2.1.1 (teclado), 2.4.6 (cabeçalhos e rótulos),
2.4.7 (foco visível), 2.5.7 (movimentos de arrastar)
e 4.1.2 (nome, função e valor).

## Escopo e método

A auditoria de código examinou a navegação compartilhada, autenticação,
configurações, tarefas/Kanban, ponto e trilha de auditoria. Os testes de
widget verificam rótulos, propriedades semânticas, operação, contraste de
texto sobre fundos translúcidos e comportamento em larguras reduzidas.
A inspeção estática inclui a análise Dart de `frontend/lib` e `frontend/test`.

O smoke `frontend/test/browser/first_paint_smoke.mjs` usa Chrome real,
build de produção e a árvore de acessibilidade exposta pelo navegador. Verifica
nomes/funções de login, navegação por Tab/Shift+Tab, acionamento de revelar
senha e validação por Enter, controles sem corte horizontal em viewports
de 320/360/600 pixels, transição login/cadastro e quadros efetivamente
renderizados nos temas claro/escuro. Pode ser reproduzido após
`flutter build web --release` com `node test/browser/first_paint_smoke.mjs`.

Também foi executada inspeção interativa do build local em Chrome, compilado
com `--dart-define=API_BASE_URL="$TOUCHIN_TEST_API_URL"` e autenticado com
uma conta administrativa de seed (sem registrar credenciais no repositório).
Foram conferidos, na árvore de acessibilidade do Chrome:

- Administração de equipe: rótulos de busca e ações, `aria-current=true`
  ao selecionar outro funcionário, ausência de overflow em 320/390/1440 px.
- Configurações: três controles `radio`, alternância via Espaço e valores
  `aria-checked` sincronizados; tema escuro restaurado depois do teste.
- Kanban: cartões de seed expõem `Ações do card #...`; Enter abre opções
  `menuitem` para mover entre posições/colunas e editar/excluir. Nenhuma
  movimentação ou exclusão foi executada durante a inspeção.
- Ponto: títulos, status da jornada, localização e ações de registro
  presentes na árvore semântica; nenhum registro de ponto foi criado.

A trilha de auditoria retornou HTTP 404 da API publicada, impedindo a
validação autenticada da paginação no navegador contra esse backend.
A regressão de foco durante carregamento foi testada com uma API falsa e
resposta assíncrona controlada no Flutter.

Esta auditoria de implementação não certifica conformidade integral às
WCAG 2.2 AA. O smoke automatizado cobre telas públicas sem autenticação;
páginas protegidas também foram inspecionadas interativamente em Chrome com
seed real e testadas em widgets Flutter com APIs falsas. A validação
manual de foco visível e anúncio por VoiceOver/NVDA permanece pendente.
O atalho de zoom no Chrome controlado por automação não alterou a escala;
as verificações de 320/360/600 pixels demonstram refluxo em viewports menores,
mas não comprovam zoom real de 200% a 400%. Ainda é necessário percorrer
manualmente as telas autenticadas, zoom e tecnologias assistivas com dados
representativos.

## Defeitos comprovados e tratamento

| Área | Evidência anterior | Tratamento | Critério relacionado |
| --- | --- | --- | --- |
| Seleção compartilhada | O campo anunciava um rótulo sem explicitar a opção selecionada no nó semântico | Nó semântico com rótulo, valor, estado expandido e ação; evita duplicação do evento do `InkWell` | 4.1.2 |
| Navegação compartilhada | O botão de menu na versão compacta não tinha `tooltip` | Nome acessível `Abrir menu` e cabeçalhos identificados semanticamente | 2.4.6, 4.1.2 |
| Auditoria administrativa | Seis campos de filtro em uma única `Row` ficavam comprimidos em viewport estreito; a página isolada não tinha menu de navegação | Campos refluem por largura, filtros têm rolagem própria e a página utiliza o contêiner de navegação compartilhado | 1.4.10, 2.4.6 |
| Auditoria administrativa | A paginação dependia de arrastar/rolar a lista | Controle explícito `Carregar mais eventos`, mantendo carregamento por rolagem | 2.1.1 |
| Auditoria administrativa | A substituição do botão por spinner durante paginação destruía o alvo do foco | O botão continua montado e focável enquanto a busca executa; estado de carregamento tem anúncio semântico e teste com futuro controlado | 2.4.3, 4.1.3 |
| Administração de equipe | O botão para limpar a busca não tinha nome acessível e a seleção de funcionário era indicada apenas por cor | Tooltip `Limpar busca` e estado semântico `selected` no item de funcionário | 1.4.1, 4.1.2 |
| Autenticação | Botões de revelar senha com nomes ambíguos e falhas de formulário sem aviso semântico | Ações nomeadas por campo, títulos identificados, mensagens `liveRegion` e disposição adaptada à ampliação de texto | 1.3.1, 1.4.10, 4.1.2 |
| Kanban | Arrastar era a única interação disponível para mover cartões | Menu acionável pelo teclado para mover verticalmente ou entre colunas, com as mesmas permissões do fluxo existente | 2.1.1, 2.5.7 |
| Preferência de tema | Falha de persistência não era anunciada por leitor de tela | Mensagem semântica `liveRegion` e grupo de seleção com estado de rádio | 4.1.2 |
| Ponto e geolocalização | Tons fixos tinham contraste insuficiente com fundos escuros translúcidos (por exemplo, erro de permissão) | Paleta de textos por tema para jornada e estados de localização, com testes de razão WCAG ≥ 4,5:1 | 1.4.3 |
| Resumo lateral | Legenda `RESUMO` com `onPrimary` a 50% não atingia 4,5:1 sobre o painel amarelo | Opacidade ajustada para 85%, testada nos temas claro e escuro | 1.4.3 |

## Verificações de regressão

- `frontend/test/accessibility_shared_test.dart`: rótulo/valor/ação do
  seletor, sua ativação/seleção pelo teclado e nome do botão de navegação no
  layout compacto.
- `frontend/test/admin_employees_page_test.dart`: nome acessível para limpar
  a busca e estado selecionado da ficha de funcionário.
- `frontend/test/admin_audit_page_test.dart`: refluxo dos filtros em
  viewport de 360 pixels e manutenção dos testes de filtros/paginação.
- Testes das áreas de autenticação, configurações e Kanban complementam
  os casos da auditoria.
- `frontend/test/features/time_tracking/presentation/time_clock_accessibility_test.dart`:
  contraste de estados de jornada, erro de geolocalização e título do resumo
  nos temas claro/escuro, incluindo composição alfa das superfícies.
- `frontend/test/browser/first_paint_smoke.mjs`: Chrome real, AX Tree, teclado,
  reflow horizontal em 320/360/600 pixels e inspeção de quadros renderizados.
- `polis doctor`, `polis plan` e os gates de testes, análise, build
  e smoke devem ser executados com a política efetiva e o CLI v6.12.0.

## Limites da intervenção

Os modelos de contrato Dart, endpoints FastAPI, payloads, mecanismos
de autorização e esquema de dados não foram alterados por esta auditoria.
Os controles de acessibilidade respeitam as operações existentes;
qualquer nova alternativa de navegação ou movimentação usa os mesmos
fluxos e permissões da interface anterior.
