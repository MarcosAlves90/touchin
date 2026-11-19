# Prévia de desenvolvimento offline

Na pasta `frontend`, execute o Flutter em **debug**, sem preparar backend,
banco, conta, segredos ou arquivos `.env`:

```powershell
flutter pub get
flutter run -d chrome
```

Escolha **Entrar na prévia de desenvolvimento**. Essa escolha aparece antes
da restauração de qualquer sessão real, inclusive ao abrir um link como
`/#/kanban` ou `/#/projects`. **Abrir login normal** abre o fluxo autenticado
habitual e requer o ambiente real. Profile e release abrem diretamente esse
fluxo habitual; não possuem entrada nem ativação de prévia por URL.

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
O preview e suas validações são locais; não é necessário publicar ou fazer deploy.

## Verificação automatizada

```powershell
flutter test test/developer_preview_entry_test.dart test/dev_preview/preview_test.dart
```

Inclui testes com HTTP real bloqueado, sessão real pré-existente preservada,
contratos e referências das fixtures, alterações locais, descarte de operações
pendentes, telas reais de loading/erro e painel estreito. Probes em processos
Dart separados comprovam a rejeição da ativação com `dart.vm.product` e
`dart.vm.profile`. A suíte completa e demais gates seguem `.polis/policy.json`.
