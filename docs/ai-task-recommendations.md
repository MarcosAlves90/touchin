# Recomendações semânticas de tarefas

## Escopo e configuração

As recomendações são opcionais, ficam desativadas para empresas sem configuração e sugerem apenas tarefas já existentes no projeto selecionado. Um administrador com `companies.manage` configura o provedor em **Administração → Sugestões de tarefas com IA** (`/admin/ai-settings`). O backend guarda a chave cifrada com `TOUCHIN_ENCRYPTION_SECRET`; a chave nunca é devolvida à interface. Testar a conexão envia apenas uma frase sintética, sem descrição de trabalho ou tarefas.

Para ativar, o administrador precisa configurar URL, modelo, credencial e confirmar o aviso de privacidade. A ativação exige uma chamada de verificação limitada que envia somente uma frase sintética, sem descrição de trabalho ou tarefas; configuração inválida impede a ativação. O provedor deve aceitar `POST /v1/embeddings`, com `model`, `input`, resposta OpenAI-compatible (`data[index].embedding`), URL HTTPS pública na porta 443. Informe a URL base, normalmente `https://api.openai.com/v1`; endpoints com caminho prefixado também são aceitos. Chat completions, reranking, HTTP, credenciais na URL, redirects e hosts privados não são suportados.

## Dados e privacidade

Somente após habilitação explícita, a API envia ao provedor configurado a descrição atual (até 1.000 caracteres) e até 80 textos das tarefas daquele projeto autorizado (nome/descrição, cada um limitado a 350 caracteres). IDs de tarefas e dados de outros projetos/empresas não são enviados. Os vetores são usados em memória para ordenação; prompts, respostas e vetores não são persistidos nem incluídos em logs/auditoria. Alterações de configuração são auditadas sem chave ou texto de atividade.

A descrição e os textos de tarefas podem conter dados sensíveis. O provedor pode processá-los fora do TouchIn e aplicar políticas próprias de retenção, localização, uso e cobrança. Informe os usuários e evite incluir senhas, dados pessoais ou informações sensíveis. O aviso também aparece no diálogo de registro de atividades. Recomendações são sugestões: a pessoa deve selecioná-las manualmente; o fluxo de ponto e a seleção manual continuam disponíveis se o provedor estiver desligado, sem resultados ou indisponível.

## Limites e operação

Cada pedido aceita no máximo 81 textos (consulta + até 80 tarefas), 48 KB de corpo, 8 MB de resposta e seis segundos de timeout; cada processo permite quatro chamadas concorrentes. O cliente espera 450 ms após a edição da descrição. Não há cache nem gravação de embeddings. O ranking usa cosseno, combina pequena parcela lexical para desempate e retorna no máximo três tarefas; o limiar pode produzir zero resultados. Similaridade não representa confiança nem substitui revisão humana.

Para interromper novas chamadas, desligue a opção ou remova a chave na tela de administração. Desligar também invalida respostas em curso antes de retornarem ao usuário. Para rollback, mantenha a configuração desativada; o registro de atividades continua usando o contrato existente (`WorkLogPayload`) e não depende do provedor. A criação/upgrade do schema adiciona uma tabela de configuração por empresa, inicialmente ausente/desativada.

## Avaliação

A fixture `backend/tests/fixtures/task_recommendation_evaluation.json` contém cinco casos sintéticos em português, incluindo paráfrases, sobreposição lexical, irrelevantes e sem correspondência. Ela não contém dados de produção. Execute primeiro o baseline determinístico, sem rede:

```sh
cd backend
.venv/bin/python -m app.services.task_recommendations
```

Para comparar com um modelo disponível, defina `TOUCHIN_TASK_RECOMMENDATIONS_API_KEY` fora do histórico do shell e informe URL/modelo compatíveis; a saída apresenta top-1, top-3, taxa de sugestões falsas e latência média por consulta para baseline e provedor:

```sh
.venv/bin/python -m app.services.task_recommendations \
  --provider-url https://api.openai.com/v1 --model <embedding-model>
```

A medição remota é opcional, requer credencial e conectividade, e deve ser executada com esta fixture sintética — nunca com registros reais. Métricas refletem somente estes exemplos e não garantem qualidade para outros idiomas, domínios ou modelos. Em testes automatizados, vetores fixos verificam ranking cosseno sem rede.
