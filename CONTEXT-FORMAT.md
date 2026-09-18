# CONTEXT-FORMAT.md — Formato Oficial do CONTEXT.md

> Este arquivo define a estrutura padrão do `CONTEXT.md`, que é a fonte central de contexto compartilhado entre humanos e agentes de IA.
> Toda atualização relevante em `CONTEXT.md` deve manter esta estrutura ou justificar a alteração da estrutura aqui primeiro.

---

## 1. Objetivo

`CONTEXT.md` documenta o estado atual do projeto para:

- alinhar humanos e agentes de IA
- reduzir ambiguidade técnica
- acelerar onboarding
- servir como fonte única de verdade para regras, arquitetura e decisões

---

## 2. Princípios de Redação

| Princípio | Descrição |
|---|---|
| Clareza | Frases curtas, termos precisos e sem jargão vago |
| Baixa redundância | Cada informação deve aparecer uma vez |
| Escaneabilidade | Títulos, listas e tabelas bem organizadas |
| Manutenção | Seções curtas e fáceis de atualizar |
| Compatibilidade com IA | Markdown simples e hierarquia explícita |

---

## 3. Estrutura Obrigatória

O `CONTEXT.md` deve seguir esta ordem:

1. Visão Geral do Projeto
2. Stack Tecnológica
3. Arquitetura
4. Estrutura de Pastas
5. Convenções de Código
6. Fluxos Críticos
7. Decisões Arquiteturais
8. Segurança
9. Ambientes
10. Integrações Externas
11. Padrões de API
12. Regras de Negócio
13. Observações para IA
14. Pendências Técnicas
15. Glossário

Se uma seção não se aplicar ao projeto, remova a seção em vez de deixá-la vazia.

---

## 4. Formato de Cada Seção

### 4.1 Visão Geral do Projeto

- Descrição curta do sistema
- Público-alvo
- Problema resolvido
- Links úteis

### 4.2 Stack Tecnológica

- Tabela com tecnologia, versão e papel
- Separar backend e frontend quando houver mais de uma stack

### 4.3 Arquitetura

- Descrever padrões e camadas
- Explicar relações entre módulos
- Registrar regras de comunicação importantes

### 4.4 Estrutura de Pastas

- Mapear diretórios principais
- Explicar a responsabilidade de cada pasta-chave
- Incluir apenas o que ajuda a navegar o projeto

### 4.5 Convenções de Código

- Nomenclatura
- Organização de imports
- Regras de tipos
- Linters e formatadores
- Convenção de commits

### 4.6 Fluxos Críticos

- Listar fluxos essenciais do sistema
- Descrever sequência e resultado esperado
- Registrar erros comuns e solução conhecida

### 4.7 Decisões Arquiteturais

- Usar formato ADR
- Sempre registrar data, contexto, decisão, alternativas e consequências

### 4.8 Segurança

- Autenticação e autorização
- Secrets
- Validação
- Proteções de transporte e headers

### 4.9 Ambientes

- Tabela com dev, staging e produção
- URL, banco, acesso e deploy

### 4.10 Integrações Externas

- Nome do serviço
- Chave ou credencial por referência
- Comportamento em falha

### 4.11 Padrões de API

- Prefixo
- Formato
- Erros
- Versionamento

### 4.12 Regras de Negócio

- Validadores
- Estados
- Transições
- Políticas de acesso

### 4.13 Observações para IA

- Arquivos gerados que não devem ser editados manualmente
- Comandos frequentes
- Sensibilidades do projeto

### 4.14 Pendências Técnicas

- Lista objetiva de tech debt
- Impacto e prioridade, quando útil

### 4.15 Glossário

- Termos específicos do domínio
- Definições curtas e consistentes

---

## 5. Regras de Manutenção

1. `CONTEXT.md` deve refletir o estado atual do projeto.
2. Se uma regra mudar, atualize `CONTEXT.md` primeiro.
3. Prefira remover informação obsoleta a acumular texto antigo.
4. Use datas em decisões e mudanças importantes.
5. Evite duplicar a mesma informação em múltiplos lugares.
6. Se o arquivo crescer demais, considere dividir a documentação por domínio.

---

## 6. Exemplo de Uso

```markdown
# CONTEXT.md — TouchIn App

- Última atualização: 2026-05-24
- Versão do documento: 1.1.0
- Mantenedor: Time Platform

---

## 1. Visão Geral do Projeto

Sistema de gerenciamento empresarial para ponto eletrônico, jornada e equipe.

---
```
