# Prévia de desenvolvimento offline

Na pasta `frontend`, ative a prévia explicitamente, sem preparar backend,
banco, conta, segredos ou arquivos `.env`:

```powershell
flutter pub get
flutter run -d chrome --dart-define=TOUCHIN_FRONTEND_DEV_MODE=true
```

Escolha **Entrar na prévia de desenvolvimento**. Essa escolha aparece antes
da restauração de qualquer sessão real, inclusive em `/#/kanban` ou
`/#/projects`. **Abrir login normal** segue para o app habitual e exige
o ambiente real. Sem a variável, com `false` ou com qualquer valor diferente
de `true`, o app abre diretamente no fluxo habitual, sem prévia por URL.
A regra vale em debug, profile e release; para ver a prévia em um build
otimizado local, use `flutter build web --release --dart-define=TOUCHIN_FRONTEND_DEV_MODE=true`.

O selo **PRÉVIA LOCAL** identifica a identidade fictícia. O botão **Controles**
abre um painel lateral rolável, que pode ser fechado sem cobrir o conteúdo.
Os mesmos widgets, rotas, parsers, skeletons e mensagens da aplicação são usados.
A tipografia usa a fonte do sistema para dispensar downloads do Google Fonts.

## Cenários

| Controle | Comportamento |
| --- | --- |
| Perfil fictício | Administrador, gestor ou funcionário; reinicia a sessão sintética. |
| Dados da página | Preenchidos, vazios ou erro identificado como `[Prévia]`. |
| Tempo das requisições | Instantâneo, atraso selecionável de 250 ms a 8 s, ou pendente sem término automático. |
| Inicialização do servidor | Pronto, atraso, indisponível, ou primeira tentativa falha e a próxima funciona. |
| Repetir inicialização | Repete a tela inicial real, mantendo o cenário dos dados da página. |
| Cancelar pendências e recarregar | Cancela solicitações pendentes e recarrega a página com tempo instantâneo. |
| Restaurar dados e cenário | Recria todas as fixtures e restaura administrador, servidor pronto e dados preenchidos instantâneos. |

Os controles de dados recarregam o conteúdo da rota atual sem repetir a espera
global do servidor. Os controles do servidor repetem apenas a inicialização;
por exemplo, servidor com atraso + dados pendentes exibe primeiro
**Aguardando o servidor** e depois o skeleton da página.

Para inspecionar skeleton → vazio/erro, selecione **Com atraso** e então o
estado desejado. Para recuperar um erro persistente, selecione **Preenchidos**;
os botões normais de tentar novamente repetem o cenário selecionado. Para
indisponível → retry → sucesso, use o cenário **Falha e sucesso ao tentar
novamente** e o botão normal **Tentar novamente**.

## Dados e interações

As fixtures têm IDs e datas fixos e nomes inteiramente fictícios: 13 pessoas,
três projetos (dois ativos), tarefas com subtarefas, participantes, colunas,
cards, registros de ponto e auditoria paginada. Filtros da interface,
paginação, edição de pessoas/projetos/tarefas, participantes e movimentação
de cards/colunas modificam somente a memória. Recarregar a aplicação ou
restaurar o cenário recria os dados originais.

Não são simulados login/cadastro reais, senhas, exportação CSV nem GPS.
Operações sem implementação retornam uma mensagem `[Prévia]` e nunca usam
uma API real como fallback. Configurações visuais podem salvar apenas
preferências locais de aparência. Nenhuma identidade/token fictício é
gravado no armazenamento de sessões, e sessões reais existentes são preservadas.

**Sair da prévia**, o ícone de fechar e o logout do workspace retornam à
escolha inicial. Para usar o ambiente real, escolha então **Abrir login normal**.
Não é preciso publicar nem fazer deploy para usar a prévia. Um build que
incorpora o flag também exibe o launcher após deploy; mantenha o flag ausente
em produção. Use dados fictícios ao compartilhar prints.

## Verificação automatizada

```powershell
flutter test test/developer_preview_entry_test.dart
flutter test --dart-define=TOUCHIN_FRONTEND_DEV_MODE=true test/developer_preview_entry_test.dart test/dev_preview
```

Inclui testes com HTTP real bloqueado, sessão real pré-existente preservada,
contratos e referências das fixtures, alterações locais, descarte de operações
pendentes, telas reais de loading/erro e painel estreito. Probes em processos
Dart separados exercitam a variável ausente, falsa, inválida e verdadeira,
inclusive com os sinalizadores de profile e release. A suíte completa e
demais gates seguem [a policy POLIS](../.polis/policy.json).
