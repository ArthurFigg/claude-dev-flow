# claude-dev-flow

Um fluxo de desenvolvimento com Claude Code construído ao longo de 5 projetos Python reais.

---

## O problema que este fluxo resolve

Quando comecei a usar Claude Code, o resultado era inconsistente. Às vezes a IA acertava, às vezes inventava coisas, às vezes implementava algo completamente diferente do que eu queria.

O problema não era a IA. Era ausência de contexto.

A IA não sabia o que o projeto fazia, quais módulos existiam, o que podia ou não podia tocar, quais decisões já tinham sido tomadas. Cada conversa começava do zero.

Este fluxo resolve isso: antes de qualquer código, o projeto tem um briefing (CLAUDE.md), as features têm especificações verificáveis (specs), e cada sessão começa com um resumo automático do estado atual. A IA passa a implementar o que foi decidido — não o que ela acha mais provável.

---

## O que está neste repositório

```
claude-dev-flow/
  CLAUDE.md                    # configuração global de desenvolvimento (adapte antes de usar)
  docs/
    fluxo.md                   # guia completo do fluxo com contexto de cada etapa
  .claude/
    skills/
      auditar-claude-md/       # valida o CLAUDE.md antes de qualquer código
      dominio/                 # propõe entidades, glossário e contextos (uma vez por projeto)
      contrato/                # (projeto web) define a superfície da API: recursos, endpoints, schemas
      spec/                    # especifica uma feature com critérios verificáveis
      spec-review/             # revisa o conjunto de specs em paralelo, define ordem
      planejar-setup/          # decide versão do Python, deps e estrutura de pastas
      implementar/             # decide inline vs agente por score e implementa a spec
      spec-close/              # roda pytest + revisão de diff, marca concluída, commita
      reabrir-spec/            # reabre uma spec concluída para nova revisão
      encerrar-projeto/        # encerramento formal: pytest + README + tag de versão
      session-start/           # briefing de retomada: testes + git + specs em 25 linhas
      git-skill/               # commit semântico com revisão de diff
      readme/                  # gera README baseado nos arquivos reais do projeto
    agents/
      revisor-codigo.md         # subagente read-only: audita o diff antes de cada commit
      verificador-spec.md       # subagente read-only: verifica specs em paralelo no spec-review
      implementador-spec.md     # subagente Sonnet: implementa specs grandes isoladas do contexto principal
    hooks/
      check-spec-revisao.ps1    # bloqueia edição de código com spec "Revisão: pendente"
    settings.json.example       # como registrar o hook acima num projeto (copie e adapte)
```

---

## Como usar

### 1. Adapte o CLAUDE.md global

O `CLAUDE.md` na raiz deste repositório é o arquivo global do autor — opinionado e testado em 5 projetos Python. Leia o bloco de aviso no topo antes de usar.

Copie para `~/.claude/CLAUDE.md` (Windows: `C:\Users\<usuario>\.claude\CLAUDE.md`) após adaptar ao seu contexto.

### 2. Instale as skills

Cada pasta em `.claude/skills/` contém um `Skill.md`. Para ativar cada skill como um slash command no Claude Code, copie o `Skill.md` para a pasta global de comandos com o nome da skill:

```
~/.claude/commands/auditar-claude-md.md
~/.claude/commands/dominio.md
~/.claude/commands/contrato.md
~/.claude/commands/spec.md
~/.claude/commands/spec-review.md
~/.claude/commands/planejar-setup.md
~/.claude/commands/implementar.md
~/.claude/commands/spec-close.md
~/.claude/commands/reabrir-spec.md
~/.claude/commands/encerrar-projeto.md
~/.claude/commands/session-start.md
~/.claude/commands/git-skill.md
~/.claude/commands/readme.md
```

> Alternativamente, cada skill pode ser instalada como `~/.claude/skills/{nome}/Skill.md` (mesmo conteúdo) — é o formato usado neste repositório.

No Windows, `~/.claude/` equivale a `C:\Users\<usuario>\.claude\`.

### 3. (Opcional) Ative os agentes e o hook de gate

Os subagentes são chamados automaticamente pelas skills: `revisor-codigo` e `verificador-spec` pelo `spec-close`/`spec-review` (só leitura), e `implementador-spec` pelo `implementar` quando a spec é grande (score ≥ 6). Para ativá-los, copie os arquivos para `~/.claude/agents/`:

```
~/.claude/agents/revisor-codigo.md
~/.claude/agents/verificador-spec.md
~/.claude/agents/implementador-spec.md
```

O hook (`.claude/hooks/check-spec-revisao.ps1`) bloqueia edição de código enquanto alguma spec do projeto estiver com `Revisão: pendente`. Ele é opcional e configurado **por projeto**, não globalmente: copie a pasta `.claude/hooks/` para o seu projeto e registre o hook copiando `.claude/settings.json.example` para `.claude/settings.json` do projeto (ajuste o caminho se necessário — `${CLAUDE_PROJECT_DIR}` é resolvido automaticamente pelo Claude Code).

Sem essas duas coisas o fluxo funciona igual — elas são reforço automático dos gates que as skills já fazem sozinhas por instrução.

### 4. Crie um CLAUDE.md para o seu projeto

Antes de qualquer código, crie um `CLAUDE.md` na raiz do projeto descrevendo o que ele faz, a stack, os módulos previstos e as convenções específicas. Quanto mais preciso, menos a IA vai adivinhar.

---

## O fluxo em 8 etapas

```
1. Criar CLAUDE.md do projeto
2. /auditar-claude-md     → valida gaps e inconsistências antes de codar
3. /dominio               → propõe entidades, glossário e contextos (uma vez por projeto)
   /contrato              → (só projeto web) define a superfície da API antes das specs de endpoint
4. /spec                  → especifica cada feature (repetir para cada uma)
5. /spec-review           → revisa o conjunto em paralelo (subagentes), detecta conflitos, define ordem
6. /planejar-setup        → decide deps e estrutura de pastas, documenta no CLAUDE.md
7. Para cada spec: /implementar (inline ou agente, por score) → /spec-close (pytest + revisão do diff → commita)
8. /session-start         → no início de cada sessão subsequente
   /encerrar-projeto      → quando o projeto estiver pronto para release
```

Se o hook opcional estiver ativo, a etapa 5 também vira uma barreira técnica: nenhuma edição de código passa enquanto houver spec com `Revisão: pendente` — não é mais só uma instrução que a IA segue por texto.

Detalhes de cada etapa, incluindo o que a IA faz internamente e os conceitos por trás de cada decisão: [`docs/fluxo.md`](docs/fluxo.md).

---

## Projetos onde este fluxo foi testado

Cada um desses projetos foi desenvolvido com uma versão deste fluxo, do CLAUDE.md inicial ao commit final:

| Projeto | O que faz |
|---|---|
| Bestiário D&D | Consome API Open5e, armazena monstros localmente, consultas via terminal |
| Clipboard Manager | Monitora clipboard em background, histórico pesquisável com suporte a texto, imagem e arquivo |
| content-report-ai | Detecta CSV do Instagram, processa métricas, gera PDF e envia por email |
| FormMaster | Plataforma web de formulários com triagem automática via IA |
| hardware_monitor | Monitor de CPU/RAM/disco em tempo real com interface gráfica e notificações |

O fluxo foi refinado a cada projeto. A versão aqui é o que ficou depois das 5 iterações.

---

## Inspirações

Este fluxo não foi inventado do zero. É uma adaptação de práticas existentes ao contexto de desenvolvimento solo com IA:

- **Spec-driven development** — separar decisão de execução antes de escrever código
- **Domain Driven Design (DDD)** — organizar código por domínio/feature, não por tipo de arquivo
- **Atomic commits** — um commit por mudança lógica completa, não por sessão de trabalho
- **Test-driven development (TDD)** — testes como gate para commitar, não como etapa opcional
- **Context engineering** — tratar o CLAUDE.md e as specs como infraestrutura, não como documentação opcional

O que este fluxo adiciona: a cola entre esses conceitos dentro do Claude Code — skills que executam cada etapa de forma consistente e um CLAUDE.md global que define as regras uma vez para todos os projetos.

---

## Licença

MIT
