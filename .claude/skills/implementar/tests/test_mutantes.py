import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from mutantes import Mutante, ler_mutantes, motivo_invalido, rodar_mutante  # noqa: E402

COMANDO_TESTE = f'"{sys.executable}" -m pytest -q -p no:cacheprovider'


@pytest.fixture
def projeto(tmp_path):
    (tmp_path / "conta.py").write_text(
        "def maior_de_idade(idade):\n    return idade >= 18\n", encoding="utf-8"
    )
    (tmp_path / "test_conta.py").write_text(
        "from conta import maior_de_idade\n\n"
        "def test_dezoito_e_maior():\n    assert maior_de_idade(18)\n",
        encoding="utf-8",
    )
    return tmp_path


def test_ler_mutantes_tolera_cerca_e_texto_em_volta_retorna_lista():
    texto = 'Aqui estao:\n```json\n[{"arquivo": "a.py", "original": "x", "mutante": "y"}]\n```'
    assert ler_mutantes(texto) == [Mutante("a.py", "x", "y", "")]


def test_ler_mutantes_sem_lista_retorna_vazio():
    assert ler_mutantes("não consegui") == []


def test_ler_mutantes_item_sem_campo_obrigatorio_e_ignorado():
    assert ler_mutantes('[{"arquivo": "a.py", "original": "x"}]') == []


def test_motivo_invalido_arquivo_de_teste_recusa(projeto):
    m = Mutante("test_conta.py", "18", "19", "")
    assert motivo_invalido(projeto, m) == "arquivo de teste"


def test_motivo_invalido_trecho_repetido_recusa(projeto):
    m = Mutante("conta.py", "a", "b", "")
    assert motivo_invalido(projeto, m).startswith("trecho aparece")


def test_motivo_invalido_trecho_unico_aceita(projeto):
    m = Mutante("conta.py", ">= 18", "> 18", "")
    assert motivo_invalido(projeto, m) is None


def test_rodar_mutante_pego_pelos_testes_retorna_morto(projeto):
    m = Mutante("conta.py", ">= 18", "> 18", "")
    assert rodar_mutante(projeto, m, COMANDO_TESTE) == "MORTO"


def test_rodar_mutante_nao_pego_retorna_sobreviveu(projeto):
    m = Mutante("conta.py", ">= 18", ">= 17", "")
    assert rodar_mutante(projeto, m, COMANDO_TESTE) == "SOBREVIVEU"


def test_rodar_mutante_devolve_arquivo_original(projeto):
    antes = (projeto / "conta.py").read_bytes()
    rodar_mutante(projeto, Mutante("conta.py", ">= 18", "> 18", ""), COMANDO_TESTE)
    assert (projeto / "conta.py").read_bytes() == antes
