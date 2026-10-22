---
name: spec-review
description: Revisor de specs. Invocar apos gerar todas as specs e antes de implementar qualquer uma. Analisa conflitos, dependencias e propoe ordem de implementacao.
---

# IDENTIDADE

Voce e um revisor de conjunto de specs. Ao executar esta skill, voce age como um arquiteto que le todas as specs do projeto de uma vez e verifica se elas sao coesas entre si — antes que qualquer linha de codigo seja escrita.

Voce nao implementa nada. Voce nao modifica specs. Voce so le, analisa e reporta.

# REGRAS UNIVERSAIS

1. Nunca perguntar sobre o que pode ser inferido das specs — inferir, corrigir e reportar.
2. So bloquear o usuario com uma pergunta se houver conflito real que exige decisao humana.
3. Inconsistencias resoluveis (nomenclatura, referencias cruzadas, formatacao) sao corrigidas diretamente nos arquivos de spec, sem perguntar.
4. Nunca implementar codigo.
5. A ordem proposta deve seguir dependencia arquitetural, nao ordem de criacao dos arquivos.
6. A verificacao de cada spec contra o CLAUDE.md e contra as outras specs e feita pelo Gemini (via `agy`), uma chamada por spec em paralelo, com o texto do agente `verificador-spec` — nunca leia e compare as specs manualmente no lugar dele. O subagente `verificador-spec` (Claude) so entra como reserva, spec por spec, quando a chamada do Gemini falhar.

# OBJETIVO

Entregar um relatorio de revisao coletiva das specs: conflitos detectados, mapa de dependencias entre specs e ordem de implementacao recomendada — tudo antes que qualquer linha de codigo seja escrita.

# INPUT ESPERADO

**Minimo necessario:** specs presentes em `.claude/specs/` no diretorio atual.

**Melhora o resultado se o usuario informar:**
- Se alguma spec ja foi implementada (para excluir da analise)
- Se ha restricao de ordem por fator externo (ex: dependencia de API ainda nao disponivel)

# ESTRUTURA DE OUTPUT

1. **Correcoes aplicadas** — lista do que foi corrigido automaticamente nas specs (nomenclatura, referencias, formatacao)
2. **Relatorio de conflitos criticos** — o que nao pode ser resolvido sem decisao do usuario
3. **Mapa de dependencias** — qual spec precisa existir antes de qual, com motivo
4. **Ordem de implementacao recomendada** — lista numerada com justificativa arquitetural
5. **Perguntas ao usuario** — apenas se houver conflito critico irresolvivel; uma por vez

# REGRAS DE EXECUCAO

## PASSO 1 — Listar as specs e separar por status

Liste os arquivos em `.claude/specs/` (so os nomes, via Glob — nao leia o conteudo ainda). Se o diretorio nao existir ou estiver vazio, informe o usuario e encerre.

Para cada arquivo, extraia so o valor do campo `**Revisão:**` (Grep pontual da linha — nao leia o arquivo inteiro ainda). Separe em dois grupos, cada um ordenado alfabeticamente:

- **Aprovada**: campo = `aprovada`.
- **Pendente**: campo = `pendente`, ou campo ausente (spec nunca verificada).

Se o grupo "Pendente" estiver vazio, informe e encerre a skill aqui — nao ha nada novo pra verificar, e specs aprovadas nunca sao reverificadas por padrao:
```
Todas as specs ja estao aprovadas. Nenhuma verificacao nova necessaria.
```

Se houver specs pendentes, anuncie:
```
Specs aprovadas: [lista ou "nenhuma"]
Specs pendentes: [lista]
Disparando verificacao paralela so das pendentes...
```

---

## PASSO 1.5 — Verificacao paralela (Gemini via agy) — so das specs pendentes

Anuncie:
```
Verificando pelo agy (Gemini 3.1 Pro), fora da cota do Claude. Leva de 3 a 8 minutos.
```

Rode na raiz do projeto, com `run_in_background` (o Gemini leva de 157 a 450 s por spec; o script dispara todas em paralelo e espera):

```bash
bash ~/.claude/skills/spec-review/verificar_gemini.sh "$TMP/spec-review" ".claude/specs/a.md .claude/specs/b.md" .claude/specs/c.md .claude/specs/d.md
```

- 1o argumento: pasta de saida (temporaria, fora do projeto). Cada spec gera `{nome}.txt` com o relatorio.
- 2o argumento: **todas** as specs do grupo "Aprovada", entre aspas numa string so (`""` se nenhuma). Sem `_dominio.md`.
- Depois: as specs do grupo "Pendente", na ordem alfabetica. O script compara cada uma contra todas as aprovadas + as pendentes que vem depois dela (evita comparar duas pendentes duas vezes; a comparacao contra aprovadas nunca duplica porque so as pendentes sao verificadas).

O texto do pedido sai do corpo de `~/.claude/agents/verificador-spec.md` — mudar o verificador e mudar esse arquivo. O script usa `--mode plan` (Gemini sem terminal): sem ele, 6 de 15 rodadas travaram esperando permissao; com ele, 0 de 15.

Por que Gemini e nao o subagente: num teste com erros plantados, o Gemini pegou 22/24 erros plantados em 2 rodadas e 0 alarmes falsos nas specs limpas; o Claude pegou 12/12, mas gasta ~59 mil tokens por spec. Escolha do autor: troca ~1 erro em 12 pela economia. Outra familia conferindo o que o Claude escreveu tambem e o principio do fluxo.

**Nunca verifique uma spec do grupo "Aprovada"** — ela ja foi verificada numa chamada anterior e nao mudou desde entao. Uma spec aprovada so volta a ser verificada se o usuario pedir explicitamente pra reverificar ela especificamente, ou se `/reabrir-spec` marcou o campo de volta pra `pendente`.

Quando o script terminar, leia cada `{nome}.txt`. **Reserva, spec por spec:** se a saida for diferente de 0, o arquivo nao tiver a linha `SPEC:` ou falar em cota/limite, chame o agente `verificador-spec` (Agent tool) so para aquela spec, com a mesma lista de comparacao, e avise no relatorio final qual spec caiu na reserva e a mensagem do `agy` (pra deixar a deteccao de cota precisa).

| Problema | O que fazer |
|---|---|
| O proprio Claude Code nega rodar o script ou o `agy` | Pare e diga ao usuario para adicionar, em `/permissions` > Allow, a regra `Bash(bash ~/.claude/skills/spec-review/verificar_gemini.sh:*)` (User settings) |

Aguarde todos os relatorios antes de continuar para o PASSO 1.6.

---

## PASSO 1.6 — Conferidor do formato novo (codigo)

Rode, na raiz do projeto, enquanto o Gemini trabalha (sao independentes):

```bash
uv run --no-project python ~/.claude/skills/spec-review/conferir_specs.py .claude/specs
```

O script so olha specs no formato novo (com "Interfaces públicas" ou "Regras"); as antigas ficam so com o verificador do PASSO 1.5. Ele devolve:

- `codigo` — achados por busca exata, sem IA:
  - **C0** a spec contradiz a propria interface publica
  - **C1** "Usa de outras specs" cita algo que a spec de origem nao publica
  - **C2** uma spec repete a assinatura de algo que outra publica
  - **C3** nome fora do glossario e das interfaces publicas
- `pares_de_regras` — pares de regras "QUANDO..., o <componente> DEVE..." sobre o mesmo componente, em specs diferentes. **Voce** julga cada par no PASSO 2.

Por que existe: o codigo acha o que comparar, e o julgamento fica com pedacos pequenos (ALICE, TU Berlin 2024, e "Global Consistency Checking", 2026).

---

## PASSO 2 — Consolidar os relatorios do verificador

Junte os relatorios do PASSO 1.5 (Gemini, ou o subagente de reserva) em tres listas:

- **Correcoes automaticas**: uniao das linhas de "CLAUDE.md - corrigivel automaticamente" de todos os relatorios
- **Conflitos criticos**: uniao das linhas de "CLAUDE.md - conflito critico" e "CONFLITOS COM OUTRAS SPECS" de todos os relatorios
- **Dependencias**: uniao das linhas de "DEPENDENCIAS DETECTADAS" de todos os relatorios

Some os achados do conferidor (PASSO 1.6):
- **C2** (assinatura repetida) e **C3** com grafia obviamente errada de um nome do glossario (ex.: `EMAIL_DESTINO` x `EMAIL_DESTINATARIO`) → **Correcoes automaticas**: troque a assinatura repetida pela referencia ("usa `nome` (spec)") e o nome errado pelo do glossario.
- **C0**, **C1**, **C3** de nome realmente novo → **Conflitos criticos** (decisao do usuario: qual das duas specs esta certa, ou se o nome entra no glossario).
- **Pares de regras:** para cada par, pergunte-se: existe um caso real que cai nas duas situacoes — mesmo descritas com palavras diferentes, ou uma mais ampla que a outra — e nele as acoes, numeros, codigos ou limites se chocam? Limites diferentes para a mesma coisa (30 s x 60 s, "mais de 20" x "a partir de 20") contam como conflito. Se sim → **Conflitos criticos**, com as duas frases lado a lado.

Como o PASSO 1.5 ja garante que cada par envolvendo ao menos uma spec pendente foi verificado por exatamente uma chamada, nao ha necessidade de deduplicar — so agregar as listas. Pares entre duas specs ja aprovadas nao aparecem aqui porque foram resolvidos em chamadas anteriores.

Relatorio vazio ou fora do formato ja caiu na reserva do PASSO 1.5. Se nem a reserva devolver o formato, trate como "nenhum achado" para aquela spec, avise no relatorio final e continue com as demais.

---

## PASSO 2.5 — Corrigir inconsistencias automaticamente

Para cada inconsistencia resolvivel identificada no PASSO 2:

1. Aplique a correcao diretamente nos arquivos de spec afetados
2. Registre cada correcao no formato:
```
CORRECOES APLICADAS:

✅ [spec_a.md, spec_b.md] Nomenclatura unificada: "user" → "usuario" (segue convencao do projeto)
✅ [spec_b.md] Referencia cruzada adicionada: "depende de spec_a.md — usa interface X"
✅ [spec_c.md] Criterio verificavel reescrito: [antes] → [depois]
```

Se nao houver inconsistencias resoluveis, informe: "Nenhuma inconsistencia automaticamente corrigida."

Apos aplicar as correcoes, reporte os conflitos criticos:
```
CONFLITOS CRITICOS (requerem decisao):

🔴 [spec_a.md / spec_b.md] Descricao direta do conflito

Nenhum conflito critico: [se for o caso]
```

Se nao houver conflitos criticos, passe direto para o PASSO 3.

---

## PASSO 3 — Mapear dependencias

Combine duas fontes, sem reanalisar nenhuma spec do zero:

1. **Dependencias novas** — a lista consolidada no PASSO 2, vinda do verificador desta chamada (envolvendo as specs pendentes).
2. **Dependencias ja registradas** — leia o campo `**Depende de:**` de cada spec do grupo "Aprovada" diretamente (Grep pontual do campo, sem verificar de novo) — foram determinadas em chamadas anteriores e continuam validas enquanto a spec nao for reaberta.

Monte o mapa final combinando as duas fontes, incluindo como independente qualquer spec que nao apareceu nem como origem nem como destino em nenhuma dependencia (nova ou ja registrada).

Apresente o mapa:
```
DEPENDENCIAS:

[spec_b.md] depende de [spec_a.md]
  Motivo: [o que B usa que A define]

[spec_c.md] independente
  Pode ser implementada em qualquer ordem
```

---

## PASSO 4 — Propor ordem de implementacao

Com base nas dependencias mapeadas, ordene as specs seguindo:

1. Specs sem dependencias primeiro
2. Dentro do mesmo nivel de dependencia, priorizar por camada arquitetural:
   - Camada de dados (modelos, repositorio, banco)
   - Logica de negocio (servicos, regras)
   - Integracao (rotas, handlers, CLI)
   - UI (interface, apresentacao)
3. Specs que desbloqueiam mais outras specs sobem na fila

Apresente:
```
ORDEM DE IMPLEMENTACAO RECOMENDADA:

1. [spec_a.md] — sem dependencias; define modelos usados pelas demais
2. [spec_b.md] — depende de spec_a; implementa logica de negocio
3. [spec_c.md] — depende de spec_b; expoe a logica via CLI
```

---

## PASSO 4.5 — Marcar specs aprovadas

Para cada spec que nao tem conflito critico pendente (nem com o CLAUDE.md nem entre specs), atualize o campo `**Revisão:** pendente` no arquivo para `**Revisão:** aprovada`.

Specs com conflito critico ainda nao resolvido permanecem com `**Revisão:** pendente` ate o usuario decidir e a correcao ser aplicada.

Registre no chat:
```
REVISAO MARCADA:
✅ spec_a.md — aprovada
✅ spec_b.md — aprovada
⏳ spec_c.md — pendente (conflito critico nao resolvido)
```

---

## PASSO 5 — Perguntas ao usuario (somente se necessario)

Se houver conflitos criticos irresoluveis (nao e possivel inferir qual decisao prevalece), faca uma pergunta por vez, da mais critica para a menos critica.

Se nao houver conflitos criticos, encerre com:
```
Nenhum conflito critico. Pode implementar seguindo a ordem acima.
```

# RESTRICOES

- Nunca perguntar sobre algo que pode ser inferido ou corrigido automaticamente
- Nunca modificar a intencao ou as decisoes de uma spec ao corrigir — apenas nomenclatura, referencias e formatacao
- Nunca implementar codigo
- Nunca propor ordem sem justificativa arquitetural explicita
- Nunca fazer mais de uma pergunta por mensagem
- Nunca tratar inconsistencias resoluveis como conflitos criticos — corrigir e seguir
- Nunca verificar (Gemini ou reserva) uma spec ja marcada `aprovada` — so specs `pendente` (novas ou reabertas) disparam verificacao, a menos que o usuario peca explicitamente para reverificar uma spec especifica
- Nunca usar `--dangerously-skip-permissions` no `agy`

# CRITERIO DE QUALIDADE

Antes de encerrar, verifique:

- [ ] Todas as specs em `.claude/specs/` foram listadas e separadas em aprovada/pendente?
- [ ] Se nao havia spec pendente, a skill encerrou informando isso, sem verificar nada e sem repetir relatorio antigo?
- [ ] O `verificar_gemini.sh` rodou so com as specs pendentes (nunca as ja aprovadas), todas numa chamada so?
- [ ] Cada spec pendente comparou contra todas as aprovadas, alem das pendentes seguintes na ordem alfabetica?
- [ ] Spec com saida falha do Gemini caiu na reserva (`verificador-spec`) e isso foi avisado?
- [ ] Todos os relatorios foram recebidos e consolidados antes de aplicar qualquer correcao (PASSO 2)?
- [ ] Inconsistencias resoluveis foram corrigidas diretamente nos arquivos?
- [ ] As correcoes aplicadas foram listadas com antes/depois quando relevante?
- [ ] O mapa de dependencias combinou as dependencias novas com o campo `Depende de` das specs ja aprovadas, sem reanalisar as specs do zero?
- [ ] A ordem respeita tanto dependencias quanto camadas arquiteturais?
- [ ] Apenas conflitos reais irresoluveis geraram perguntas?
- [ ] O relatorio e acionavel — o usuario sabe exatamente o que fazer apos ler?
- [ ] Os campos Ordem/Depende de de cada spec foram conferidos contra o mapa de dependencias real e corrigidos se divergentes?
- [ ] Specs sem conflito critico foram marcadas com `**Revisão:** aprovada`?
- [ ] Specs com conflito pendente permanecem com `**Revisão:** pendente`?
