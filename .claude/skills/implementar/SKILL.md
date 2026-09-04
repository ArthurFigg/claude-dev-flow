---
name: implementar
description: Implementa uma spec aprovada, decidindo entre fazer inline (sessao atual) ou delegar a um agente Sonnet isolado, com base no score de tamanho da spec. Invocar apos o /spec-review aprovar a spec, em vez de pedir "implemente seguindo X.md" informalmente.
---

# IDENTIDADE

Voce e o ponto de decisao entre "spec aprovada" e "codigo escrito". Voce nao revisa (isso e o `/spec-review`) nem commita (isso e o `/spec-close`) — voce so decide *como* implementar e garante que a implementacao aconteca, seja voce mesmo ou um agente isolado.

# OBJETIVO

Dado o nome de uma spec aprovada, decidir entre implementar inline (na sessao atual) ou delegar ao agente `implementador-spec`, baseado no score de tamanho da spec — e entregar o codigo implementado e testado ao final, dos dois jeitos.

# INPUT ESPERADO

**Minimo necessario:** nome da spec (com ou sem extensao, com ou sem caminho), igual ao `/spec-close`.

# ESTRUTURA DE OUTPUT

1. Relatorio do `escritor-testes` (mapa criterio -> teste)
2. Confirmacao do modo escolhido (inline ou agente) com o motivo (score)
3. Resultado da implementacao (arquivos criados/modificados, testes)
4. Instrucao pra proximo passo (`/spec-close`)

# A ORDEM E O PONTO

Teste primeiro, implementacao depois, **por atores diferentes**. Nao e cerimonia: quando a mesma passada escreve o codigo e o teste, o teste passa a confirmar o codigo em vez da spec, e um criterio mal entendido fica verde nos dois lados sem ninguem notar. Separar os dois papeis e o unico jeito de o `pytest` do `/spec-close` significar alguma coisa.

Por isso o `escritor-testes` roda **sempre**, independente do score. Ele le a spec, nao o projeto — e barato.

# REGRAS DE EXECUCAO

## PASSO 1 — Ler a spec e confirmar aprovacao

Normalize o input pro caminho `.claude/specs/{nome}.md`. Leia o arquivo completo.

Se `**Revisão:**` nao estiver `aprovada`, pare e informe:
```
Esta spec ainda nao foi aprovada (Revisão: {status atual}).
Rode /spec-review antes de implementar.
```

## PASSO 2 — Obter o score de tamanho

Verifique se o campo `**Score:**` existe no cabecalho da spec.

**Se existir:** use o valor direto, nao recalcule.

**Se nao existir** (spec criada antes desta regra): calcule usando os mesmos criterios do `/spec` (PASSO 3.7) a partir da secao "Modulos afetados":

| Item | Pontos |
|---|---|
| Cada arquivo Python significativo (>30 linhas esperadas) | +1 |
| Cada template HTML | +1 |
| Cada arquivo CSS | +1 |
| Arquivo JavaScript nao-trivial (>50 linhas esperadas) | +2 |
| Arquivo JavaScript trivial (<50 linhas) | +1 |

Adicione o campo `**Score:** {valor}` ao cabecalho da spec (junto de `Ordem`/`Depende de`/`Revisão`), pra futuras chamadas nao precisarem recalcular.

## PASSO 3 — Escrever os testes (sempre, antes de qualquer codigo)

Chame o agente `escritor-testes` (via Agent tool), passando o caminho da spec e o diretorio do projeto.

Anuncie antes de disparar:
```
Escrevendo os testes a partir dos criterios da spec, antes da implementacao.
```

Exiba o relatorio dele integralmente — principalmente o mapa criterio -> teste, que e o que permite conferir se a spec foi lida direito.

**Dois casos param a skill aqui:**

- **Criterios sem teste** — algum criterio verificavel ficou descoberto. Mostre quais e pergunte ao usuario se segue assim ou se a spec precisa de ajuste antes.
- **Ambiguidade reportada** — o agente achou criterio que aceita mais de uma leitura. Mostre a ambiguidade e deixe o usuario decidir. Ambiguidade de spec e decisao dele, nunca sua.

Se algum teste **passou** nesta etapa, avise: ou o comportamento ja existia, ou o teste nao verifica nada. Nao siga sem o usuario olhar.

## PASSO 4 — Decidir e executar a implementacao

O score conta arquivos, um proxy grosseiro do volume de escrita. Antes de decidir,
faca um ajuste de bom senso: se o numero de arquivos e o volume real esperado
divergem muito — poucos arquivos mas muito codigo (ex: 1 modulo de ~300 linhas) ou
muitos arquivos triviais (ex: 6 de ~30 linhas) — voce pode mover a decisao em ate
1 ponto na direcao do volume real, anunciando o motivo. O score persistido no
cabecalho NAO muda; so a decisao inline/agente desta execucao. Na duvida, siga o score.

**Score ≤ 5 — implemente inline, voce mesmo:**

Leia primeiro os testes que o `escritor-testes` acabou de escrever — eles sao a leitura mais precisa da spec que existe. Depois siga a spec: "Comportamento", "Modulos afetados", "Nao mexer". Leia o CLAUDE.md do projeto pras convencoes.

Escreva o codigo ate os testes passarem. **Nao edite nenhum arquivo em `tests/`** — a mesma regra que vale pro agente vale pra voce, e pelo mesmo motivo: teste que voce pode ajustar volta a confirmar o teu codigo. Teste que parece errado vira pergunta ao usuario, nunca edicao.

Implemente tambem o comportamento descrito na spec que nenhum teste cobriu — teste ausente nao autoriza comportamento ausente.

Anuncie antes de comecar:
```
Score {X} — implementando inline (abaixo do custo de delegar a um agente).
```

**Score ≥ 6 — delegue ao agente:**

Chame o agente `implementador-spec` (via Agent tool), passando o caminho da spec, o diretorio do projeto e os caminhos dos arquivos de teste ja escritos. Aguarde o relatorio completo.

Anuncie antes de disparar:
```
Score {X} — delegando ao agente implementador-spec (Sonnet).
```

Exiba o relatorio recebido do agente integralmente ao usuario.

## PASSO 5 — Conferir que os testes nao foram mexidos

Antes de orientar o proximo passo, confirme que `tests/` continua como o `escritor-testes` deixou:

```
git diff --stat -- tests/
```

Se aparecer qualquer alteracao ali, **avise o usuario em destaque**. Teste alterado durante a implementacao anula a separacao inteira: o `pytest` verde do `/spec-close` deixa de provar que a spec foi cumprida. Mostre o diff e deixe ele decidir se reverte.

Se o projeto ainda nao tiver git inicializado, pule esta conferencia e diga que pulou.

## PASSO 6 — Orientar proximo passo

Ao final, com os testes passando e `tests/` intacto:
```
Implementacao concluida. Para fechar: /spec-close {nome da spec}
```

Se os testes nao passaram, exiba os erros e nao sugira `/spec-close` ainda — o gate de testes dele vai bloquear mesmo assim, mas nao adianta rodar sabendo que vai falhar.

**Se houver teste em conflito** (o agente reportou que um teste contradiz a spec), nao sugira `/spec-close` nem mande consertar o teste. Mostre o conflito e pergunte ao usuario qual dos dois esta errado — a spec ou o teste. Conflito assim quase sempre e ambiguidade da spec aparecendo, e resolver isso e decisao dele.

# RESTRICOES

- Nunca commitar nada — isso e exclusividade do `/spec-close`
- Nunca implementar spec com `Revisão` diferente de `aprovada`
- **Nunca pular o `escritor-testes`**, nem pra spec pequena, nem pra "so um ajuste"
- **Nunca escrever ou editar arquivo em `tests/`** depois que o `escritor-testes` entregou
- Nunca recalcular o score se o campo `**Score:**` ja existir no arquivo
- Nunca pular a leitura do CLAUDE.md antes de implementar inline
- Nunca omitir o relatorio do agente quando a implementacao for delegada

# CRITERIO DE QUALIDADE

Antes de encerrar, verifique:

- [ ] A spec foi confirmada como `aprovada` antes de qualquer implementacao?
- [ ] O `escritor-testes` rodou **antes** de existir uma linha de codigo?
- [ ] O mapa criterio -> teste foi mostrado ao usuario, e nenhum criterio ficou sem teste?
- [ ] O score foi lido do campo existente ou calculado e persistido, nunca recalculado a toa?
- [ ] A decisao inline/agente foi anunciada com o motivo (score, mais o ajuste de bom senso se houve)?
- [ ] `git diff --stat -- tests/` confirmou que os testes nao foram alterados na implementacao?
- [ ] Os testes foram rodados e o resultado real (nao suposto) foi reportado?
- [ ] O proximo passo (`/spec-close`) so foi sugerido se os testes passaram e nao ha teste em conflito?
