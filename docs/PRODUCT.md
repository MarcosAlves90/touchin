# Fluxos do TouchIn

Este guia resume o comportamento do código versionado. Permissões e escopo
são verificados pela API; o que aparece na interface depende da conta, da
empresa e do recurso acessado.

## Ponto e histórico

- A sequência usual é **Entrada** (`checkIn`) → **Pausa** (`breakStart`) →
  **Retorno** (`breakEnd`) → **Saída** (`checkOut`). A API valida a transição
  a partir do último evento. Funcionários configurados com localização
  obrigatória precisam enviar a localização na batida.
- **Entrada** e **Retorno** não têm projeto ou tarefas. **Pausa** e **Saída**
  podem ter contexto de trabalho. Ao fechar um período trabalhado, a API exige
  o registro de atividades; quando há projeto, as tarefas devem pertencer a
  esse projeto e ele precisa estar disponível para o funcionário.
- O histórico próprio e o histórico de equipe exibem projeto e tarefas
  quando disponíveis. Tarefas são mostradas com ID quando o histórico o
  preserva; registros antigos sem ID não recebem um identificador presumido.
  Os `WorkLog` preservam o histórico de trabalho mesmo quando o vínculo
  ativo com uma batida ou funcionário é removido.
- Consulte [o serviço de ponto](../backend/app/services/time_clock.py) e
  [a projeção de histórico](../backend/app/domain/time_clock_read.py) para
  os casos de edição administrativa, transições e dados legados.

## Projetos, tarefas e participantes

A área **Projetos e tarefas** reúne os projetos acessíveis à conta, suas
tarefas e participantes. A área do projeto inclui Kanban, backlog e
relatório de atividades. Consultar um projeto não concede automaticamente
permissão para editar, alterar participantes ou administrar o quadro;
consulte [as permissões da API](../backend/app/authorization.py).

### Busca de tarefas e sugestões de IA

- **Busca de tarefas:** o texto digitado no Kanban/backlog é interpretado
  no frontend. A busca ignora maiúsculas/minúsculas e normaliza acentos
  comuns; combina termos em título/descrição com tipos ou colunas
  reconhecidos e com o número do card (por exemplo, `#42`). Use
  `tipo:bug` para explicitar o tipo. Não há chamada a um modelo externo.
  Veja [TaskSearchQuery](../frontend/lib/features/projects/presentation/task_search_query.dart).
- **Sugestões de tarefas:** no registro de atividades, quando a empresa
  habilita a integração, a descrição pode ser comparada com até 80 tarefas
  do projeto selecionado via embeddings. São oferecidas até três sugestões.
  O usuário decide se vai selecionar uma delas, e a seleção manual não
  depende do provedor. Veja [configuração, limites e privacidade](ai-task-recommendations.md).

## Trilha de auditoria

Eventos da empresa são acessíveis com a permissão `audit.read`. Autor,
entidade e projeto aceitam pesquisa parcial por ID ou por nome quando o
nome pode ser resolvido. Data, ação, tipo e resultado complementam o
filtro. Os eventos usam timestamps em UTC no contrato; o app apresenta
datas e horas no fuso local do navegador. A exportação CSV usa os mesmos
filtros, mas não se limita à página atual. Se exceder o limite de bytes
do ambiente (teto de 1 MiB), restrinja os filtros e tente de novo.

Veja [as rotas e parâmetros](../backend/app/api/routes/audit.py) e
[a resolução de nomes](../backend/app/domain/audit_read.py). As chaves
`actor_user_id`, `entity_id` e `project_id` ainda mantêm esses nomes
na API, mesmo quando a consulta recebe texto.
