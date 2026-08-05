# Template — `_decisoes.md`

> Compartilhado por `/dominio`, `/contrato`, `/planejar-setup`, `/spec-close`
> (escrevem) e `/session-start`, `/readme` (leem). Nenhuma skill repete os
> criterios abaixo: elas apontam para este arquivo.
>
> Destino no projeto: `.claude/specs/_decisoes.md`

---

## Criterio de corte

Uma pergunta, aplicada no momento em que a decisao e tomada:

> **A decisao restringe codigo que ainda vai ser escrito, em mais de uma spec?**

- **Sim** -> entra no `_decisoes.md`
- **Nao** -> fica na secao "Decisoes tomadas" da spec de origem

Duas exclusoes que evitam o inchaco:

1. **Regra que o CLAUDE.md global ja impoe nao entra.** Codigo em portugues, teto
   de versao em dep de producao, pytest sempre, sem `except Exception: pass`.
   Nada disso foi decidido no projeto — foi obedecido. Registrar transforma o
   arquivo em copia do CLAUDE.md global, e copia diverge.
2. **Decisao de uma spec so nao entra**, mesmo que seja boa. O lugar dela ja
   existe.

**Teste de cheiro:** passou de ~10 entradas num projeto, o criterio afrouxou.
Reveja antes de acrescentar a proxima.

## Criterio de legibilidade

> **Quem nunca viu o projeto le uma entrada e entende a decisao e o motivo sem
> abrir outro arquivo.**

Se precisou abrir a spec, o `_dominio.md` ou o CLAUDE.md pra fazer sentido, a
entrada falhou. Na pratica:

- **Titulo diz a decisao, nao o tema** — "SQLite em vez de PostgreSQL", nunca
  "Banco de dados".
- **Contexto em uma ou duas frases**, no nivel de quem decidiu.
- **Entrada auto-contida** — sem "conforme a Spec 3", sem sigla que so existe no
  glossario.
- **Sem jargao cerimonial** — "o custo e migrar depois", nao "o trade-off
  identificado impacta a manutenibilidade".

## Regras de escrita

1. **Campo que o usuario nao disse nao e escrito.** `Custo aceito` e
   `Descartado` sao os mais faceis de preencher de forma plausivel e errada —
   sao opiniao sobre o futuro, nao fato verificavel. Se nao apareceu na conversa,
   o campo fica de fora. Campo ausente e honesto; campo inventado estraga o
   arquivo inteiro.
2. **Escrever no momento da decisao**, nunca reconstruir depois. Contexto e
   alternativa descartada so estao vivos na hora.
3. **Sem numeracao, sem status, sem `superseded`.** Decisao que muda e editada
   no lugar; o historico e do git.
4. **Nunca commitar.** Quem commita e o `/spec-close` ou o `/git-skill`.
5. **Criar o arquivo se ele nao existir**, com o cabecalho do bloco abaixo.
   Se ja existir, apenas acrescentar a entrada no fim.

---

## Bloco a escrever no projeto

Cabecalho (so na criacao do arquivo):

```markdown
# Decisoes transversais — {nome do projeto}

> Mantido pelas skills do fluxo conforme as decisoes sao tomadas. Lido pelo
> `/session-start` e destilado pelo `/readme` na secao "Decisoes tecnicas".

**Entra aqui** a decisao que restringe codigo de mais de uma spec.
**Nao entra** decisao de uma spec so (fica na spec), nem regra que o CLAUDE.md
global ja impoe — obedecer nao e decidir.

Cada entrada se explica sozinha: quem nunca viu o projeto entende a decisao e o
motivo sem abrir outro arquivo.
```

Entrada (a cada decisao que passa no criterio de corte):

```markdown
## {A decisao, nao o tema}

**Contexto:** {a forca que existia na hora — uma ou duas frases}
**Decisao:** {o que foi escolhido, concreto}
**Descartado:** {alternativa real considerada + por que caiu — omitir se nao houve}
**Custo aceito:** {o que essa escolha cobra depois — omitir se nao foi discutido}
```

Exemplo preenchido (referencia de tom, nao vai pro projeto):

```markdown
## SQLite em vez de PostgreSQL

**Contexto:** projeto de portfolio; quem clona precisa rodar sem Docker nem
servico externo.
**Decisao:** SQLite com tipos genericos do SQLAlchemy (`Uuid`, `JSON`) e
`create_all` no startup.
**Descartado:** PostgreSQL — so se ganharia `LISTEN/NOTIFY` e `pgvector`, e o
projeto nao usa nenhum dos dois.
**Custo aceito:** migrar depois exige trocar os tipos e introduzir Alembic.
```
