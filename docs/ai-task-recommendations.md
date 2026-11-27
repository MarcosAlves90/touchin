# Recomendações semânticas de tarefas

## Escopo e configuração

As recomendações são opcionais, ficam desativadas para empresas sem configuração e sugerem apenas tarefas já existentes no projeto selecionado. Uma conta com `companies.manage` configura o provedor em **Administração → Sugestões de tarefas com IA** (`/admin/ai-settings`). O backend guarda a chave cifrada com `TOUCHIN_ENCRYPTION_SECRET`; a chave nunca é devolvida à interface. Testar a conexão envia apenas uma frase sintética, sem descrição de trabalho ou tarefas. A chave salva só pode ser usada no mesmo host HTTPS. Para mudar de host, substitua ou remova a chave ao salvar; para testar outro host, informe a chave explicitamente.

Para ativar, o administrador precisa configurar URL, modelo, credencial e confirmar o aviso de privacidade. A ativação exige uma chamada de verificação limitada que envia somente uma frase sintética, sem descrição de trabalho ou tarefas; configuração inválida impede a ativação. O provedor deve aceitar `POST` em um endpoint compatível com a API OpenAI, com `model` e `input`, e retornar itens `data` contendo `index` e `embedding`. Informe uma URL HTTPS pública na porta 443, como `https://api.openai.com/v1`. O backend normaliza o caminho para terminar em `/v1/embeddings`, preservando prefixos. Chat completions, reranking, HTTP, credenciais na URL, redirects e hosts privados não são suportados.

## Dados e privacidade

Somente após habilitação explícita, a API envia ao provedor configurado a descrição atual (até 1.000 caracteres) e até 80 textos das tarefas daquele projeto autorizado (número do card, quando houver, nome e descrição, truncados juntos a 350 caracteres por tarefa). IDs internos de tarefas e dados de outros projetos/empresas não são enviados. Os vetores são usados em memória para ordenação; prompts, respostas e vetores não são persistidos nem incluídos em logs/auditoria. Alterações de configuração são auditadas sem chave ou texto de atividade.

A descrição e os textos de tarefas podem conter dados sensíveis. O provedor pode processá-los fora do TouchIn e aplicar políticas próprias de retenção, localização, uso e cobrança. Informe os usuários e evite incluir senhas, dados pessoais ou informações sensíveis. O aviso também aparece no diálogo de registro de atividades. Recomendações são sugestões: a pessoa deve selecioná-las manualmente; o fluxo de ponto e a seleção manual continuam disponíveis se o provedor estiver desligado, sem resultados ou indisponível.

## Limites e operação

O backend só consulta o provedor a partir de dois termos distintos reconhecidos na descrição. As candidatas são limitadas a 80 tarefas do projeto, ordenadas pelo ID interno. Cada chamada aceita até 81 textos (consulta + tarefas), 48.000 bytes de corpo e 8.000.000 bytes de resposta. A troca com o provedor tem prazo total de seis segundos, incluindo DNS, conexão e leitura; cada processo permite quatro chamadas concorrentes. O banco limita as recomendações a 30 tentativas por usuário em cada empresa e 300 no total por empresa, a cada hora do relógio (UTC), compartilhadas entre sessões e processos. Ao atingir um limite, as sugestões ficam indisponíveis até a próxima hora, sem afetar o registro manual. Testes de conexão e verificação administrativa não usam essa cota de recomendações. O cliente espera 450 ms após a edição da descrição. Não há cache nem gravação de embeddings. O ranking combina similaridade por cosseno (85%) e sobreposição lexical (15%). Os limiares podem produzir zero resultados; são retornadas no máximo três tarefas. Similaridade não representa confiança nem substitui revisão humana.

Para interromper novas chamadas, desligue a opção ou remova a chave na tela de administração. Desligar também invalida respostas em curso antes de retornarem ao usuário. Para rollback, mantenha a configuração desativada; o registro de atividades continua usando o contrato existente (`WorkLogPayload`) e não depende do provedor. A criação/upgrade do schema adiciona uma tabela de configuração por empresa, inicialmente ausente/desativada.

## Referências no código

- [`task_recommendations.py`](../backend/app/services/task_recommendations.py): seleção de candidatas, cota e ranking.
- [`secure_provider.py`](../backend/app/services/secure_provider.py): chamada e limites ao provedor externo.
- [`work_log_dialog.dart`](../frontend/lib/features/time_tracking/presentation/work_log_dialog.dart): aviso e sugestões no registro de atividades.

A [busca do Kanban/backlog](PRODUCT.md#busca-de-tarefas-e-sugestões-de-ia) é outro recurso: ela interpreta filtros e termos localmente, sem embeddings nem provedor.

## Avaliação

A fixture `backend/tests/fixtures/task_recommendation_evaluation.json` contém cinco casos sintéticos em português, incluindo paráfrases, sobreposição lexical, irrelevantes e sem correspondência. Ela não contém dados de produção. Execute primeiro o baseline lexical, sem rede. Use as dependências e a configuração local do [backend](DEVELOPMENT.md#preparar-o-backend), com a venv ativa. A avaliação não precisa conectar ao banco, mas a importação do módulo exige a configuração do backend:

```sh
cd backend
python -m app.services.task_recommendations
```

Para comparar com um modelo disponível, defina `TOUCHIN_TASK_RECOMMENDATIONS_API_KEY` fora do histórico do shell (só para esta ferramenta de avaliação) e informe URL/modelo compatíveis; a saída apresenta top-1, top-3, taxa de sugestões falsas e latência média por consulta para baseline e provedor:

```sh
python -m app.services.task_recommendations \
  --provider-url https://api.openai.com/v1 --model NOME_DO_MODELO
```

A medição remota é opcional, requer credencial e conectividade, e deve ser executada com esta fixture sintética — nunca com registros reais. Métricas refletem somente estes exemplos e não garantem qualidade para outros idiomas, domínios ou modelos. Em testes automatizados, vetores fixos verificam ranking cosseno sem rede.
