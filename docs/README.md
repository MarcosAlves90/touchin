# Documentação do TouchIn

## Guias vigentes

| Quero… | Onde consultar |
| --- | --- |
| Entender ponto, Kanban/backlog, busca e auditoria | [Fluxos do produto](PRODUCT.md) |
| Rodar a aplicação, testes ou CI localmente | [Desenvolvimento](DEVELOPMENT.md) |
| Explorar a UI com dados fictícios | [Prévia offline](DEVELOPER_PREVIEW.md) |
| Consultar variáveis e rotas da API | [Backend](../backend/README.md) |
| Configurar build, banco, e-mail e deploy | [Deploy](DEPLOYMENT.md) |
| Ativar sugestões de tarefas e entender o envio ao provedor | [Recomendações semânticas](ai-task-recommendations.md) |
| Localizar módulos e convenções | [Contexto](../CONTEXT.md) e [formato de contexto](../CONTEXT-FORMAT.md) |
| Conferir origens das imagens de autenticação | [Fotografias da autenticação](../frontend/docs/auth-images.md) |
| Reproduzir a comparação visual canônica | [Goldens de navegação](../frontend/test/goldens/rounded_workspace_navigation/README.md) |

## Contratos, relatórios e evidências

[Contratos POLIS](contracts/) registram requisitos no momento de cada mudança.
[Evidências por issue](validation/) registram o que foi verificado na revisão
correspondente. Os relatórios de [acessibilidade](accessibility-issue-64.md),
[performance](performance/VALIDATION_REPORT.md) e
[segurança, ponto e navegação](security-timeclock-navigation-traceability.md),
assim como o [score report de primeiro paint](../SCORE_REPORT.md), são
registros históricos. Seus resultados, ambiente, limitações e instruções de
reprodução não certificam a versão atual.

Referências executáveis prevalecem sobre resumos: confira
[o workflow CI](../.github/workflows/ci.yml), [a policy POLIS](../.polis/policy.json),
[as configurações do backend](../backend/app/config.py) e
[as rotas da API](../backend/app/api/router.py) para o comportamento atual.
Não atualize baselines ou evidências anteriores para fazê-las parecer atuais.
