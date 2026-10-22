#!/usr/bin/env bash
# Verifica as specs pendentes pelo Gemini (agy), uma chamada por spec, em paralelo.
# Uso (na raiz do projeto): verificar_gemini.sh PASTA_SAIDA "aprovadas..." pendente1 pendente2 ...
# Cada pendente compara contra todas as aprovadas + as pendentes que vem depois dela.
# O texto do pedido e o corpo do agente verificador-spec.md (fonte unica).
# --mode plan: bloqueia o terminal; sem ele, 6 de 15 rodadas travaram (teste de 10/10).

SAIDA="$1"; APROVADAS="$2"; shift 2
AGY=~/AppData/Local/agy/bin/agy.exe
CORPO=$(awk 'f>=2{print} /^---$/{f++}' ~/.claude/agents/verificador-spec.md)
mkdir -p "$SAIDA"

PENDENTES=("$@")
for i in "${!PENDENTES[@]}"; do
  ALVO="${PENDENTES[$i]}"
  OUTRAS="$APROVADAS ${PENDENTES[*]:$((i + 1))}"
  NOME=$(basename "$ALVO" .md)
  PEDIDO="RULE 0: you have NO terminal and must NOT use the web. Any terminal command is denied and ENDS the task with no output. Use only view_file / list_dir. Do NOT write any file; print the report only.

$CORPO

ENTRADA:
- Spec alvo: $ALVO
- CLAUDE.md do projeto: CLAUDE.md
- Outras specs do lote: ${OUTRAS:-nenhuma}"
  (
    INI=$(date +%s)
    "$AGY" -p "$PEDIDO" --model gemini-4-argon-high --mode plan \
      --print-timeout 900s > "$SAIDA/$NOME.txt" 2>&1
    echo "$NOME saida=$? segundos=$(( $(date +%s) - INI ))"
  ) &
done
wait
