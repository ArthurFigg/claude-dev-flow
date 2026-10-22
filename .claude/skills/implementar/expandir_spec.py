"""Monta a "spec expandida": a spec + as interfaces que ela usa, copiadas das specs de origem.

Uso: uv run --no-project python expandir_spec.py .claude/specs/<nome>.md
Grava .claude/specs/_expandidas/<nome>.md e imprime o caminho.

Por que: no formato novo cada interface e escrita uma vez so (na spec que cria), mas quem
implementa ou escreve teste precisa dela por perto. A colagem traz SO o que a spec usa —
spec completa melhora o agente (WiseSpec, 2026: +13%), spec inchada piora (Constraint
Decay, 2026: -27 pontos).
"""

import re
import sys
from pathlib import Path


def secao(texto: str, titulo: str) -> str:
    achado = re.search(rf"(?ms)^## {titulo}\s*$(.*?)(?=^## |\Z)", texto)
    return achado.group(1) if achado else ""


def linhas_da_interface(texto_origem: str, nome: str) -> list[str]:
    return [
        linha.strip()
        for linha in secao(texto_origem, "Interfaces públicas").splitlines()
        if re.match(rf"\s*-\s*`(?:[\w.]+\.)?{re.escape(nome)}\b", linha)
    ]


def expandir(caminho: Path) -> tuple[str, list[str]]:
    texto = caminho.read_text(encoding="utf-8")
    pasta = caminho.parent
    coladas, faltando = [], []
    for nome, origem in re.findall(r"`(\w+)` \((\w+)\)", secao(texto, "Usa de outras specs")):
        arquivo = next(iter(sorted(pasta.glob(f"{origem}*.md"))), None)
        linhas = linhas_da_interface(arquivo.read_text(encoding="utf-8"), nome) if arquivo else []
        if linhas:
            coladas += [f"{l}  _(de {origem})_" for l in linhas if f"{l}  _(de {origem})_" not in coladas]
        else:
            faltando.append(f"`{nome}` ({origem})")
    if not coladas and not faltando:
        return texto, []
    apendice = "\n\n## Interfaces usadas (copiadas automaticamente das specs de origem)\n"
    apendice += "\n".join(coladas) if coladas else "- nenhuma encontrada"
    return texto.rstrip() + apendice + "\n", faltando


def main() -> int:
    caminho = Path(sys.argv[1])
    texto, faltando = expandir(caminho)
    destino = caminho.parent / "_expandidas" / caminho.name
    destino.parent.mkdir(exist_ok=True)
    destino.write_text(texto, encoding="utf-8")
    print(destino.as_posix())
    for item in faltando:
        print(f"AVISO: interface nao encontrada na spec de origem: {item}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
