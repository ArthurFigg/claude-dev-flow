# claude-dev-flow

Um fluxo de desenvolvimento com Claude Code construído ao longo de vários projetos reais.

Em termos de hoje, é um trabalho de *harness engineering*: tudo o que fica em volta do modelo (regras, specs, testes, travas, conferências) para que ele entregue o que foi pedido. O harness usa dois modelos: o **Claude** escreve as specs e os testes e confere o resultado; o **Gemini**, pelo `agy` (Antigravity CLI), escreve o código e confere as specs. Quem não tem o `agy` usa a variante só-Claude (ver `variantes/so-claude/`).

---

## O problema que este fluxo resolve

Quando comecei a usar Claude Code, o resultado era inconsistente. Às vezes a IA acertava, às vezes inventava coisas, às vezes implementava algo completamente diferente do que eu queria.

O problema não era a IA. Era ausência de contexto.

A IA não sabia o que o projeto fazia, quais módulos existiam, o que podia ou não podia tocar, quais decisões já tinham sido tomadas. Cada conversa começava do zero.

Este fluxo resolve isso: antes de qualquer código, o projeto tem um briefing (CLAUDE.md), as features têm especificações verificáveis (specs), e cada sessão começa com um resumo automático do estado atual. A IA passa a implementar o que foi decidido — não o que ela acha mais provável.

---

## Por que dois modelos: Claude + Gemini (agy)

### Economia

Escrever código é a parte que mais gasta token. No fluxo, quem escreve é o Gemini, pelo `agy`, que roda na cota dele. O Claude só lê o resultado e confere.

O mesmo vale para a revisão das specs. Conferir uma spec com o Claude custava cerca de 59 mil tokens; com o Gemini, sai da cota do Claude. Num teste com erros escondidos de propósito em specs, o Gemini achou 22 de 24 e o Claude, 12 de 12. A troca aceita é perder cerca de 1 erro em 12 em troca da economia.

### Código melhor, porque quem escreve não confere

Um modelo tende a aprovar o próprio trabalho. Pesquisas mostram que modelos dão nota maior aos próprios textos e aos da mesma família ([Play Favorites, 2025](https://arxiv.org/abs/2508.06709)), e que, avaliando por uma lista de critérios, aprovam com mais facilidade um critério que falhou quando o texto é deles ([Self-Preference Bias in Rubric-Based Evaluation, 2026](https://arxiv.org/abs/2604.06996)).

Por isso cada papel fica com um ator diferente:

| Papel | Quem |
|---|---|
| Escrever a spec | Claude, com você |
| Escrever os testes, antes do código | Claude (agente `escritor-testes`), lendo só a spec |
| Escrever o código | Gemini, sem permissão para mexer em `tests/` |
| Conferir o código contra a spec | Claude, que não escreveu aquele código |

O que isso deu na prática:

- Em 17 rodadas num projeto real, o Gemini nunca alterou um teste. A trava é dupla: permissão negada no `agy` e uma impressão digital (hash) dos testes conferida no fim.
- A leitura do Claude pegou um atalho que os testes deixaram passar: código escrito só para o nome aparecer no arquivo.
- Medido em 21/10/2026: com 9 erros escondidos que passam em todos os testes, a conferência do Claude achou 8.

As pesquisas e os testes de cada peça importante do fluxo estão em [`docs/provas.md`](docs/provas.md) (versão para baixar: [`docs/provas.pdf`](docs/provas.pdf)).

Ressalva: não há medição de que o Gemini escreve código melhor que o Claude. O ganho vem de separar quem escreve de quem confere. Sem o `agy`, a variante só-Claude mantém a separação entre teste e código, mas perde a separação entre famílias de modelo.

---

## O que está neste repositório

```
claude-dev-flow/
  CLAUDE.md                    # configuração global de desenvolvimento (adapte antes de usar)
  docs/
    fluxo.md                   # guia completo do fluxo com contexto de cada etapa
  .claude/
    skills/
      pesquisar-projeto/       # (opcional, ideia nova) avalia se vale a pena e como fazer, antes do CLAUDE.md
      auditar-claude-md/       # valida o CLAUDE.md antes de qualquer código
      dominio/                 # propõe entidades, glossário e contextos (uma vez por projeto)
      contrato/                # (projeto web) gera openapi.yaml (OpenAPI 3.1): recursos, endpoints, schemas
      spec/                    # especifica uma feature com critérios verificáveis
      spec-review/             # Gemini confere cada spec + script acha conflitos entre specs; define ordem
      planejar-setup/          # decide versão do Python, deps e estrutura de pastas
      implementar/             # testes antes (escritor-testes), Gemini escreve o código, Claude confere, testa os testes
      spec-close/              # roda pytest + revisão de diff, marca concluída, commita
      reabrir-spec/            # reabre uma spec concluída para nova revisão
      encerrar-projeto/        # encerramento formal: pytest + README + CHANGELOG + tag
      session-start/           # briefing de retomada: testes + git + specs em 25 linhas
      git-skill/               # commit semântico com revisão de diff
      readme/                  # gera README baseado nos arquivos reais do projeto
      diagrama/                # diagrama Mermaid (arquitetura + ER) em região marcada do README
    templates/
      _decisoes.md             # critério de corte e formato do registro de decisões transversais
    agents/
      escritor-testes.md        # subagente Sonnet: escreve os testes da spec antes de existir código
      revisor-codigo.md         # subagente read-only: audita o diff antes de cada commit
      verificador-spec.md       # subagente read-only: verifica specs em paralelo no spec-review
      implementador-spec.md     # subagente: reserva do Gemini quando a cota do agy acaba
    hooks/
      check-spec-revisao.ps1    # bloqueia edição de código com spec "Revisão: pendente"
    settings.json.example       # como registrar o hook acima num projeto (copie e adapte)
  gemini/
    GEMINI.md                   # regras do Gemini como implementador (vai em ~/.gemini/)
    settings.json.example       # permissões do agy: o que ele pode escrever e rodar
  variantes/
    so-claude/                  # implementar + spec-review sem o agy (versão de 27/09)
```

---

## Como usar

### 1. Adapte o CLAUDE.md global

O `CLAUDE.md` na raiz deste repositório é o arquivo global do autor — opinionado e testado em vários projetos Python. Leia o bloco de aviso no topo antes de usar.

Copie para `~/.claude/CLAUDE.md` (Windows: `C:\Users\<usuario>\.claude\CLAUDE.md`) após adaptar ao seu contexto.

### 2. Instale as skills

Cada pasta em `.claude/skills/` contém um `SKILL.md`. Copie as pastas inteiras para `~/.claude/skills/`, mantendo o nome — cada uma vira um slash command (`/spec`, `/implementar`...):

```
~/.claude/skills/pesquisar-projeto/SKILL.md
~/.claude/skills/auditar-claude-md/SKILL.md
~/.claude/skills/dominio/SKILL.md
~/.claude/skills/contrato/SKILL.md
~/.claude/skills/spec/SKILL.md
~/.claude/skills/spec-review/SKILL.md
~/.claude/skills/planejar-setup/SKILL.md
~/.claude/skills/implementar/SKILL.md
~/.claude/skills/spec-close/SKILL.md
~/.claude/skills/reabrir-spec/SKILL.md
~/.claude/skills/encerrar-projeto/SKILL.md
~/.claude/skills/session-start/SKILL.md
~/.claude/skills/git-skill/SKILL.md
~/.claude/skills/readme/SKILL.md
~/.claude/skills/diagrama/SKILL.md
```

> O nome do arquivo é em maiúsculas: no Linux, `Skill.md` não é encontrado e a skill simplesmente não carrega, sem erro. O formato antigo `~/.claude/commands/{nome}.md` ainda funciona, mas não é o usado aqui.

Copie também `.claude/templates/_decisoes.md` para `~/.claude/templates/_decisoes.md`. Ele não é uma skill: é o template que `/dominio`, `/contrato`, `/planejar-setup` e `/spec-close` consultam para saber o que entra no registro de decisões transversais do projeto. O critério mora nesse arquivo único justamente para não ser copiado dentro de quatro skills e desalinhar na primeira edição.

No Windows, `~/.claude/` equivale a `C:\Users\<usuario>\.claude\`.

### 3. (Opcional) Ative os agentes e o hook de gate

Os subagentes são chamados automaticamente pelas skills: `revisor-codigo` e `verificador-spec` pelo `spec-close`/`spec-review` (só leitura), e `escritor-testes` + `implementador-spec` pelo `implementar`. Para ativá-los, copie os arquivos para `~/.claude/agents/`:

```
~/.claude/agents/escritor-testes.md
~/.claude/agents/revisor-codigo.md
~/.claude/agents/verificador-spec.md
~/.claude/agents/implementador-spec.md
```

> O `escritor-testes` é o único que não é opcional na prática: sem ele o `/implementar` não tem os testes prontos para a implementação fazer passar, e a separação entre quem escreve o teste e quem escreve o código deixa de existir.

O hook (`.claude/hooks/check-spec-revisao.ps1`) bloqueia edição de código enquanto alguma spec do projeto estiver com `Revisão: pendente`. Ele é opcional e configurado **por projeto**, não globalmente: copie a pasta `.claude/hooks/` para o seu projeto e registre o hook copiando `.claude/settings.json.example` para `.claude/settings.json` do projeto (ajuste o caminho se necessário — `${CLAUDE_PROJECT_DIR}` é resolvido automaticamente pelo Claude Code).

Sem essas duas coisas o fluxo funciona igual — elas são reforço automático dos gates que as skills já fazem sozinhas por instrução.

### 4. Instale o agy (Gemini)

O `/implementar` e o `/spec-review` chamam o Gemini pelo `agy` (Antigravity CLI), fora da cota do Claude.

1. Instale o `agy` e faça o login. As skills procuram em `~/AppData/Local/agy/bin/agy.exe` (Windows); em outro sistema, ajuste esse caminho nos dois `SKILL.md`.
2. Copie `gemini/GEMINI.md` para `~/.gemini/GEMINI.md`. São as regras do implementador: não mexer em `tests/`, não rodar `git`, parar com `PRECISO DE AJUDA` quando travar.
3. Copie `gemini/settings.json.example` para `~/.gemini/antigravity-cli/settings.json` e acrescente as pastas de código dos seus projetos em `allow`. No modo sem janela, o que não está liberado é negado e o Gemini para.

Sem o `agy`, use `variantes/so-claude/` (veja o `LEIA-ME.md` de lá).

### 5. Crie um CLAUDE.md para o seu projeto

Antes de qualquer código, crie um `CLAUDE.md` na raiz do projeto descrevendo o que ele faz, a stack, os módulos previstos e as convenções específicas. Quanto mais preciso, menos a IA vai adivinhar.

---

### 6. (Opcional) Fila de propostas de melhoria

Peça separada, com repositório próprio: [fila-propostas](https://github.com/ArthurFigg/fila-propostas). A IA anota as falhas do próprio fluxo com a prova, e você decide uma por uma o que muda. Não precisa do resto deste fluxo.

---

## O fluxo em 8 etapas

```
0. /pesquisar-projeto     → (opcional, ideia nova) pesquisa se vale a pena e como fazer; você decide seguir, pesquisar mais ou largar
1. Criar CLAUDE.md do projeto
2. /auditar-claude-md     → valida gaps e inconsistências antes de codar
3. /dominio               → propõe entidades, glossário e contextos (uma vez por projeto)
   /contrato              → (só projeto web) define a superfície da API antes das specs de endpoint
4. /spec                  → especifica cada feature (repetir para cada uma)
5. /spec-review           → Gemini confere cada spec em paralelo, script acha conflitos, define ordem
6. /planejar-setup        → decide deps e estrutura de pastas, documenta no CLAUDE.md
7. Para cada spec: /implementar (testes → Gemini escreve → Claude confere → relatório) → /spec-close (pytest + relatório + diff → commita)
8. /session-start         → no início de cada sessão subsequente
   /diagrama              → quando a arquitetura estabilizar, desenha o mapa no README
   /encerrar-projeto      → quando o projeto estiver pronto para release
```

### Dois artefatos que o fluxo mantém sozinho

Nenhum dos dois é uma etapa: as skills que já existem escrevem neles conforme o projeto anda.

**`.claude/specs/_decisoes.md`** — as decisões que restringem mais de uma spec, escritas no momento em que são tomadas, com a alternativa descartada e o custo aceito. `/dominio`, `/contrato` e `/planejar-setup` escrevem; `/spec-close` promove o que for de altitude arquitetural; `/session-start` lê no briefing; `/readme` destila na seção "Decisões técnicas". O critério de corte é uma pergunta só — *a decisão restringe código de mais de uma spec?* — e regra que o CLAUDE.md global já impõe não entra, porque obedecer não é decidir.

**`CHANGELOG.md`** — formato [Keep a Changelog](https://keepachangelog.com/) + SemVer. `/spec-close` escreve uma linha em `## [Não lançado]` a cada spec fechada, em nível de usuário; `/encerrar-projeto` renomeia a seção para a versão da tag. A linha sai do "O que faz" da spec, não da mensagem de commit — commit descreve implementação, spec descreve o que a pessoa passa a conseguir fazer.

Se o hook opcional estiver ativo, a etapa 5 também vira uma barreira técnica: nenhuma edição de código passa enquanto houver spec com `Revisão: pendente` — não é mais só uma instrução que a IA segue por texto.

Detalhes de cada etapa, incluindo o que a IA faz internamente e os conceitos por trás de cada decisão: [`docs/fluxo.md`](docs/fluxo.md).

---

## Alguns projetos feitos com este fluxo

O fluxo já foi usado em muitos projetos. Estes são alguns exemplos, cada um feito do CLAUDE.md inicial ao commit final:

| Projeto | O que faz |
|---|---|
| Bestiário D&D | Consome API Open5e, armazena monstros localmente, consultas via terminal |
| Clipboard Manager | Monitora clipboard em background, histórico pesquisável com suporte a texto, imagem e arquivo |
| content-report-ai | Detecta CSV do Instagram, processa métricas, gera PDF e envia por email |
| FormMaster | Plataforma web de formulários com triagem automática via IA |
| hardware_monitor | Monitor de CPU/RAM/disco em tempo real com interface gráfica e notificações |

O fluxo foi refinado a cada projeto. A versão aqui é a mais recente.

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
