# Guia do Fluxo de Desenvolvimento com Claude Code

---

## Parte 1 — O Fluxo Completo

Este é o fluxo padrão para todo projeto Python novo. Cada etapa tem uma skill específica. Seguir a ordem evita retrabalho.

---

### Etapa 1 — Criar o CLAUDE.md do projeto

**Onde:** no Claude.ai (claude.ai), antes de abrir o Claude Code.

**O que é:** um arquivo de configuração do projeto que define o que o projeto faz, como o código deve ser escrito, quais módulos existem, convenções específicas, próximos passos planejados. É o "briefing" que a IA lê antes de qualquer tarefa.

**O que colocar:**
- Nome e objetivo do projeto
- Tipo (CLI, Web API, Desktop, Script, etc.)
- Estrutura de módulos prevista
- Convenções específicas do projeto (se diferirem do padrão global)
- Lista de features planejadas

**Onde salvar:** na raiz do projeto, como `.claude/CLAUDE.md` ou `CLAUDE.md`.

Quando terminar, abra o Claude Code dentro da pasta do projeto.

---

### Etapa 2 — `/auditar-claude-md`

**Quando:** logo após abrir o projeto no Claude Code, antes de qualquer código.

**O que faz:**
- Lê o CLAUDE.md e detecta inconsistências (regras que se contradizem)
- Detecta contexto insuficiente (algo definido de forma vaga demais)
- Verifica conflitos entre o CLAUDE.md do projeto e o CLAUDE.md global
- Se specs existirem em `.claude/specs/`, verifica consistência com elas
- Faz perguntas para preencher as lacunas (uma por vez)
- Atualiza o CLAUDE.md com as decisões
- **Relê o arquivo atualizado do zero e repete a verificação inteira**, sem exigir que você rode a skill de novo manualmente. Continua perguntando e corrigindo até uma passada completa não encontrar mais nada.
- Se a mesma contradição reaparecer em qualquer passada anterior (corrigir um lado reabre o outro — mesmo que passando por outras regras no meio do caminho), para e reporta como "loop detectado" — nesse caso a decisão de qual regra prevalece é sua, não da IA.

**Por que é importante:** um CLAUDE.md com gaps faz a IA adivinhar durante a implementação. Corrigir antes é muito mais barato que corrigir depois. Sem o reloop automático, cada correção que gerasse uma inconsistência nova (ou cada erro que passasse batido na primeira leitura) exigia rodar `/auditar-claude-md` de novo manualmente.

---

### Etapa 3 — `/dominio` (uma vez por projeto)

**Quando:** logo após o `/auditar-claude-md` aprovar o CLAUDE.md, antes da primeira `/spec`.

**O que faz:**
- Lê o CLAUDE.md e deriva candidatos a entidade a partir das features e módulos descritos (não pergunta em aberto — sempre propõe primeiro)
- Propõe as entidades ("as coisas principais que o projeto cria, armazena ou manipula") para você validar
- Propõe um glossário de termos — qual nome usar sempre e qual evitar, para não haver sinônimo divergente entre specs
- Avalia se o projeto precisa de mais de um bounded context (vocabulário e regras próprias e separadas) ou se contexto único basta — a maioria dos projetos de portfólio cai em contexto único, e isso é o esperado, não uma limitação
- Gera `.claude/specs/_dominio.md`, que o `/spec` passa a ler automaticamente

**Por que é importante:** sem isso, specs geradas em conversas separadas podem nomear a mesma coisa de dois jeitos diferentes (ex: uma spec chama de "usuário", outra de "conta"). O `_dominio.md` trava o vocabulário uma vez, no início, para todas as specs seguintes.

---

### Etapa 4 — `/spec` (repetir para cada feature)

**Quando:** para cada feature que você quer implementar.

**O que faz:**
- Lê o CLAUDE.md do projeto para entender a arquitetura
- Lê specs existentes em `.claude/specs/` para evitar conflitos
- Faz perguntas sobre o comportamento da feature (uma por vez)
- Verifica casos negativos (o que acontece com input inválido, estado errado)
- Gera o arquivo `.claude/specs/{nome_da_feature}.md`

**O que a spec contém:**
- O que a feature faz (uma frase)
- Comportamentos específicos (quando X acontece, Y deve ocorrer)
- Critérios verificáveis por comando (`pytest`, `curl`, execução direta)
- Módulos afetados e o que muda em cada um
- O que NÃO mexer
- Decisões tomadas durante a conversa

Repita esta etapa para cada feature antes de implementar qualquer uma.

---

### Etapa 5 — `/spec-review`

**Quando:** depois de gerar TODAS as specs, antes de implementar qualquer uma.

**O que faz:**
- Lista as specs em `.claude/specs/` e as ordena alfabeticamente
- Dispara um subagente `verificador-spec` **para cada spec, em paralelo** — cada instância lê a spec dela, cruza com o CLAUDE.md, e compara só com as specs que vêm depois dela na lista (assim nenhum par é verificado duas vezes por duas instâncias diferentes)
- Consolida os relatórios recebidos de todas as instâncias
- Corrige automaticamente inconsistências resolúveis (nomenclatura divergente, referências cruzadas faltando)
- Para conflitos reais que exigem decisão: reporta e pergunta
- Mapeia dependências a partir do que os subagentes já detectaram
- Propõe ordem de implementação com justificativa arquitetural

**Por que é importante:** specs geradas em chamadas separadas não se conhecem. Esta etapa garante que o conjunto é coeso antes de escrever código. Verificar em paralelo (em vez de uma spec de cada vez, sequencialmente) deixa a revisão mais rápida e não carrega o texto de todas as specs na conversa principal — só os relatórios resumidos voltam para quem chamou.

**Camada de gate opcional:** se o hook `check-spec-revisao.ps1` estiver ativo no projeto (ver seção 3.8), enquanto qualquer spec estiver com `Revisão: pendente`, o Claude Code recusa tecnicamente qualquer edição de código fora de `.claude/specs/` e do CLAUDE.md — não depende mais só da IA lembrar de checar o campo por instrução.

---

### Etapa 6 — Implementar cada spec + `/spec-close`

Para cada spec, na ordem recomendada pelo spec-review:

**a)** Diga ao Claude Code: `"implemente seguindo .claude/specs/{nome}.md"`  
A IA lê a spec e implementa o código + testes.

**b)** Quando terminar, rode: `/spec-close {nome_da_spec}`

**O que o `/spec-close` faz:**
- Lê a spec para extrair o título
- Roda: `uv run pytest -v`
- Se testes **passam**:
  - Dispara o subagente `revisor-codigo`, que lê o `git diff` da spec e reporta problemas de correção, segurança, escopo ou convenção que o pytest não pega (ex: caso de borda que a spec exige mas nenhum teste cobre, segredo hardcoded)
  - Se o revisor achar algo: mostra o achado e pergunta se você quer corrigir antes ou commitar mesmo assim — a decisão final é sua, o agente nunca corrige nem decide sozinho
  - Marca a spec como concluída no arquivo (adiciona data)
  - Faz o commit com mensagem derivada do título da spec
  - Faz push para o repositório remoto
- Se testes **falham**:
  - Lista os erros claramente
  - Bloqueia o commit
  - Você corrige e roda `/spec-close` novamente

Não commite manualmente durante o ciclo de specs. O `/spec-close` é o único caminho de commit nesta fase.

**Por que o `revisor-codigo` existe:** pytest só prova que o código roda e os asserts passam — não prova que o código faz tudo que a spec pediu. É comum os testes cobrirem o caminho feliz e esquecerem um caso de borda que a spec descreveu explicitamente. O `revisor-codigo` lê o diff a frio, sem o viés de quem acabou de escrever o código, e só tem permissão de leitura (`Read`, `Grep`, `Glob`, `Bash` restrito a comandos git de leitura) — ele fisicamente não consegue editar nada, mesmo que "quisesse".

---

### Etapa 7 — `/session-start` (sessões subsequentes)

**Quando:** toda vez que abrir o Claude Code em um projeto em andamento.

**O que faz** (tudo automaticamente, sem perguntas):
- Lê o CLAUDE.md do projeto
- Separa specs concluídas das pendentes
- Roda `git log` e `git status`
- Roda: `uv run pytest --tb=no -q`
- Entrega um briefing em menos de 25 linhas com:
  - Estado dos testes (destaque se houver falhas)
  - Último commit e mudanças não commitadas
  - Specs concluídas vs pendentes
  - Próximo passo específico e acionável

**Por que é importante:** elimina os primeiros minutos de "onde eu estava?". A IA não precisa reconstruir contexto manualmente.

---

### Referência rápida: quando usar o `/git-skill`

`/git-skill` é reservado para commits **fora** do ciclo de specs:
- Hotfix (correção urgente que não veio de uma spec)
- Ajuste de configuração (`.gitignore`, `pyproject.toml`, `.env.example`)
- Criação de tag de release (`v1.0.0`, `v1.1.0`)
- Commit inicial do projeto (antes de qualquer spec)

Durante a implementação de specs, use sempre `/spec-close`.

---

## Parte 2 — Referência Rápida das Skills

| Skill | Quando usar |
|---|---|
| `/auditar-claude-md` | Valida o CLAUDE.md antes de codar |
| `/dominio` | Propõe entidades, glossário e contextos (uma vez por projeto) |
| `/spec` | Cria a spec de uma feature |
| `/spec-review` | Revisa o conjunto de specs em paralelo (subagente `verificador-spec`), define ordem |
| `/spec-close [nome]` | Fecha uma spec: pytest + subagente `revisor-codigo` + commit |
| `/session-start` | Briefing de retomada de sessão |
| `/git-skill` | Commit fora do ciclo de specs |
| `/readme` | Gera o README.md quando o projeto estiver pronto |

Os subagentes (`revisor-codigo`, `verificador-spec`) e o hook de gate (`check-spec-revisao.ps1`) são opcionais — ver seção "Como usar" no README para ativação — e reforçam automaticamente etapas que as skills acima já cobrem por instrução.

---

## Parte 3 — O que Aprender para Entender Tudo

Esta parte explica os conceitos por trás de cada etapa do fluxo, com os termos exatos para pesquisar e aprender mais.

---

### 3.1 — O que é uma "spec" e por que ela existe

A spec (especificação de feature) é um documento que define **O QUE** implementar antes de escrever qualquer código. Ela separa a fase de decisão da fase de execução.

O conceito original vem de engenharia de software tradicional: equipes grandes escrevem especificações antes de codar para alinhar todo mundo. No fluxo com IA, a spec serve para que o Claude Code implemente exatamente o que você decidiu, sem adivinhar.

**Termos para pesquisar:**
- "Software Design Document SDD"
- "Feature Specification template"
- "Acceptance Criteria how to write"
- "BDD Behavior Driven Development" (especialmente o formato Given/When/Then)
- "Spec-driven development"
- "Requirements Engineering software"

**O que entender:** a diferença entre critérios verificáveis (`pytest` passa) e critérios vagos ("código limpo"). Specs só têm valor se os critérios puderem ser checados por um comando.

---

### 3.2 — Por que testes são o gate para commitar

O `/spec-close` só commita se os testes passam. Isso é uma prática chamada "green before commit" — você nunca commita código com testes quebrados.

A lógica: se testes passam, você tem evidência de que o código funciona como especificado. Se falham, você tem um bug documentado que precisa ser resolvido antes de avançar.

**Termos para pesquisar:**
- "Test Driven Development TDD Python"
- "pytest tutorial"
- "pytest fixtures" (como reutilizar setup entre testes)
- "pytest parametrize" (como testar múltiplos casos com um teste só)
- "what makes a good unit test"
- "test isolation Python"
- "mocking vs integration tests"

**O que entender:** a diferença entre testes unitários (testam uma função isolada), testes de integração (testam módulos juntos) e testes e2e (testam o sistema completo). O fluxo usa principalmente unitários + integração.

---

### 3.3 — Por que um commit por spec (não por sessão)

O fluxo commita uma vez por spec implementada, não uma vez por sessão de trabalho. Isso é chamado de "atomic commits" — cada commit representa uma mudança lógica completa e independente.

**Benefícios práticos:**
- `git log` conta a história do projeto (cada spec = um capítulo)
- Se uma spec introduziu um bug, dá para reverter só ela (`git revert`)
- Code review fica possível (revisar uma spec por vez)

**Termos para pesquisar:**
- "Atomic commits git"
- "Git commit best practices"
- "git log oneline graph"
- "git bisect" (como encontrar qual commit introduziu um bug)
- "git revert vs git reset"

**O que entender:** a diferença entre `git commit` (salva localmente) e `git push` (envia para o servidor remoto). E a diferença entre `git reset` (desfaz commits) e `git revert` (cria um commit que desfaz outro).

---

### 3.4 — Por que o código é organizado por domínio e não por tipo

O CLAUDE.md global define que o código deve ser organizado por feature/domínio (`usuarios/`, `produtos/`) e não por tipo de arquivo (`models/`, `views/`, `utils/`).

**A razão:** quando você precisa mexer em "usuários", tudo que precisa está em um lugar só. Na organização por tipo, você precisa abrir `models/`, `views/` e `services/` ao mesmo tempo — o código relacionado fica espalhado.

**Termos para pesquisar:**
- "Domain Driven Design DDD Python"
- "Feature-based project structure Python"
- "Separation of concerns software"
- "Cohesion coupling software design"
- "Clean Architecture Python"

**O que entender:** "coesão" (código relacionado junto) e "acoplamento" (módulos dependendo uns dos outros). Alta coesão e baixo acoplamento é o objetivo.

---

### 3.5 — Como o CLAUDE.md e as skills funcionam tecnicamente

O Claude Code lê arquivos específicos antes de cada conversa:
- **CLAUDE.md global:** em `~/.claude/CLAUDE.md` (Windows: `C:\Users\<usuario>\.claude\CLAUDE.md`)
- **CLAUDE.md do projeto:** em `.claude/CLAUDE.md` ou `CLAUDE.md` na raiz
- **Skills:** arquivos `.md` em `~/.claude/commands/` (Windows: `C:\Users\<usuario>\.claude\commands\`)

Quando você digita `/spec`, o Claude Code lê o arquivo `~/.claude/commands/spec.md` e usa o conteúdo como instrução. É essencialmente um "prompt" (instrução para a IA) salvo em arquivo.

**Termos para pesquisar:**
- "Claude Code CLAUDE.md documentation"
- "Claude Code custom slash commands"
- "Claude Code system prompt"
- "Prompt engineering guide"
- "System prompt vs user prompt"
- "Claude Code hooks" (automações que rodam em eventos, ex: antes de commitar)

**O que entender:** skills são prompts salvos em arquivo. Quando você melhora uma skill (editando diretamente o arquivo `.md`), você está refinando a instrução que a IA recebe. Quanto mais precisa a instrução, mais previsível o resultado.

---

### 3.6 — O que é "uv" e por que ele é usado no lugar de pip

`uv` é um gerenciador de pacotes Python moderno, muito mais rápido que pip. O fluxo usa `uv run pytest` em vez de `python -m pytest` ou `pytest` diretamente porque o `uv` garante que o comando roda no ambiente virtual correto do projeto.

**Termos para pesquisar:**
- "uv Python package manager"
- "uv vs pip vs pipenv vs poetry"
- "Python virtual environment" (o que é e por que existe)
- "pyproject.toml Python" (o arquivo de configuração moderno do Python)
- "Python dependency management"

**O que entender:** cada projeto Python tem suas próprias dependências. O ambiente virtual (venv) isola essas dependências para que projetos diferentes não interfiram entre si. O `uv` gerencia isso automaticamente.

---

### 3.7 — O que a IA faz quando implementa uma spec

Quando você diz `"implemente seguindo .claude/specs/busca_monstro.md"`, a IA:
1. Lê a spec completa
2. Lê o CLAUDE.md do projeto para entender a arquitetura
3. Lê o CLAUDE.md global para as convenções de código
4. Cria ou modifica os arquivos listados em "Módulos afetados"
5. Cria os testes correspondentes em `tests/`
6. Não toca no que está em "Não mexer"

A IA não "entende" o código como um humano — ela prediz o próximo token (pedaço de texto) com base no contexto. Quanto mais contexto preciso (CLAUDE.md, spec), menos ela precisa adivinhar e mais o resultado se parece com o que você quer.

**Termos para pesquisar:**
- "Large Language Models how they work"
- "AI code generation how it works"
- "Context window LLM" (o limite de texto que a IA processa de uma vez)
- "Prompt engineering for code generation"
- "AI pair programming workflow"

**O que entender:** a IA não "sabe" o que é certo — ela produz o que é estatisticamente provável dado o contexto. Por isso specs precisas e CLAUDE.md detalhado produzem resultados mais consistentes do que pedidos vagos.

---

### 3.8 — Hooks e subagentes: a camada automática opcional

Até certo ponto, este fluxo dependia só de instrução em texto (a IA lê a regra na skill e segue). Os arquivos em `.claude/agents/` e `.claude/hooks/` adicionam dois mecanismos mais fortes, ambos opcionais:

**Hook:** um script que o Claude Code executa automaticamente antes (ou depois) de uma ferramenta ser usada — por exemplo, antes de qualquer edição de arquivo. O hook deste fluxo (`check-spec-revisao.ps1`) roda antes de toda edição e verifica se existe alguma spec com `Revisão: pendente` no projeto atual. Se existir, a edição é recusada — não é um lembrete de texto que a IA pode ignorar por engano, é uma barreira técnica.

**Subagente:** uma instância separada do Claude Code, com seu próprio contexto e próprio conjunto de ferramentas, chamada de dentro de uma skill para fazer uma tarefa específica e devolver só o resultado — sem que o trabalho intermediário dela (arquivos lidos, comparações feitas) entre na conversa principal. Este fluxo usa dois: `revisor-codigo` (dentro do `/spec-close`, só leitura, sem permissão de editar nada) e `verificador-spec` (dentro do `/spec-review`, um por spec, todos rodando ao mesmo tempo). Nenhum dos dois decide sozinho — os dois só reportam, e a skill principal (ou você) decide o que fazer com o achado.

**Por que isso importa mais do que parece:** escopo restrito de ferramentas é uma garantia técnica, não uma promessa de comportamento. Um subagente sem acesso a `Edit` ou `Write` fisicamente não consegue alterar código, mesmo que "quisesse" — diferente de só instruir "não edite nada" num prompt, que depende da IA seguir a instrução.

**Termos para pesquisar:**
- "Claude Code hooks PreToolUse PostToolUse"
- "Claude Code subagents / Task tool"
- "principle of least privilege" (por que restringir ferramentas importa)
- "AI agent orchestration"
- "multi-agent systems software"

**O que entender:** a diferença entre "pedir para a IA não fazer algo" (instrução, pode falhar) e "impedir tecnicamente que a IA faça algo" (permissão restrita, não falha). Hooks e escopo de ferramentas de subagente são a segunda categoria.
