"""Testa os testes: aplica cada erro proposto pelo Gemini, roda os testes e desfaz.

Uso (na raiz do projeto):
  uv run --no-project python mutantes.py SAIDA_DO_AGY.txt "uv run pytest -x -q"

Imprime uma linha por erro: MORTO (os testes pegaram), SOBREVIVEU (passou nos testes ->
buraco) ou INVALIDO (trecho nao achado uma vez so, ou arquivo de teste). Saida 0 sempre
que todos os arquivos voltaram ao original; 2 se algum nao voltou (avise em destaque).

Por que: Google roda mutacao em toda mudanca, no code review, so nas linhas mudadas
(State of Mutation Testing at Google, 2018); Meta ACH idem, por mudanca (2501.12862).
"""

import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

LIMITE_SEGUNDOS = 300


@dataclass
class Mutante:
    arquivo: str
    original: str
    mutante: str
    descricao: str


def ler_mutantes(texto: str) -> list[Mutante]:
    """Le a lista JSON que o agy imprimiu, tolerando cerca ``` e texto em volta."""
    texto = re.sub(r"^```(?:json)?\s*|\s*```$", "", texto.strip())
    inicio = texto.find("[")
    if inicio < 0:
        return []
    itens = json.JSONDecoder().raw_decode(texto[inicio:])[0]
    return [
        Mutante(i["arquivo"], i["original"], i["mutante"], i.get("descricao", ""))
        for i in itens
        if {"arquivo", "original", "mutante"} <= i.keys()
    ]


def e_arquivo_de_teste(arquivo: str) -> bool:
    partes = Path(arquivo).parts
    return "tests" in partes or Path(arquivo).name.startswith("test_")


def motivo_invalido(raiz: Path, m: Mutante) -> str | None:
    if e_arquivo_de_teste(m.arquivo):
        return "arquivo de teste"
    caminho = raiz / m.arquivo
    if not caminho.is_file():
        return "arquivo nao existe"
    if m.original == m.mutante:
        return "erro igual ao original"
    vezes = caminho.read_text(encoding="utf-8").count(m.original)
    if vezes != 1:
        return f"trecho aparece {vezes} vezes"
    return None


def testes_passam(comando: str, raiz: Path) -> bool:
    try:
        resultado = subprocess.run(
            comando, shell=True, cwd=raiz, capture_output=True,
            timeout=LIMITE_SEGUNDOS,
        )
    except subprocess.TimeoutExpired:
        # erro que trava o codigo (laco infinito) conta como pego
        return False
    return resultado.returncode == 0


def rodar_mutante(raiz: Path, m: Mutante, comando: str) -> str:
    caminho = raiz / m.arquivo
    original = caminho.read_bytes()
    try:
        texto = original.decode("utf-8")
        caminho.write_bytes(texto.replace(m.original, m.mutante, 1).encode("utf-8"))
        return "SOBREVIVEU" if testes_passam(comando, raiz) else "MORTO"
    finally:
        caminho.write_bytes(original)


def hash_arquivo(caminho: Path) -> str:
    return hashlib.sha256(caminho.read_bytes()).hexdigest()


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")  # console do Windows quebra acento
    saida_agy, comando = Path(sys.argv[1]), sys.argv[2]
    raiz = Path.cwd()
    mutantes = ler_mutantes(saida_agy.read_text(encoding="utf-8"))
    if not mutantes:
        print("NENHUM ERRO LIDO da saida do agy")
        return 0
    if not testes_passam(comando, raiz):
        print("TESTES JA FALHAM sem nenhum erro aplicado — nada a medir")
        return 0

    arquivos = {m.arquivo for m in mutantes if (raiz / m.arquivo).is_file()}
    antes = {a: hash_arquivo(raiz / a) for a in arquivos}
    for n, m in enumerate(mutantes, 1):
        motivo = motivo_invalido(raiz, m)
        status = f"INVALIDO ({motivo})" if motivo else rodar_mutante(raiz, m, comando)
        print(f"{n}. {status} | {m.arquivo} | {m.descricao}")
        print(f"   {m.original!r} -> {m.mutante!r}")

    nao_voltaram = [a for a in arquivos if hash_arquivo(raiz / a) != antes[a]]
    if nao_voltaram:
        print(f"ATENCAO: arquivos nao voltaram ao original: {nao_voltaram}")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
