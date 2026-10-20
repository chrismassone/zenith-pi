"""Estoque: saldo, compras e consumo avulso."""
from datetime import datetime

from repositorios import estoque as repo
from servicos.atendimentos import conferir_saldo
from servicos.base import banco
from servicos.validador import Campo, validar_ou_falhar

CAMPOS_COMPRA = [
    Campo("id_insumo", "Insumo", "id"),
    Campo("id_fornecedor", "Fornecedor", "id"),
    Campo("data_compra", "Data da compra", "data"),
    Campo("quantidade", "Quantidade", "decimal", maior_que_zero=True),
    Campo("preco_unitario", "Preço unitário", "decimal", minimo=0),
    Campo("lote", "Lote", maximo=30),
    Campo("data_validade", "Data de validade", "data"),
]
CAMPOS_CONSUMO = [
    Campo("id_insumo", "Insumo", "id"),
    Campo("quantidade", "Quantidade", "decimal", maior_que_zero=True),
    Campo("observacao", "Motivo", maximo=255),
]


def estoque(sessao, busca="", so_alertas=False):
    sessao.exigir("insumos")
    with banco():
        return repo.estoque(busca, so_alertas)


def compras(sessao, busca=""):
    sessao.exigir("insumos")
    with banco():
        return repo.listar_compras(busca)


def consumos(sessao, busca=""):
    sessao.exigir("insumos")
    with banco():
        return repo.listar_consumos(busca)


def _validade_depois(d):
    if d["data_validade"] <= d["data_compra"]:
        return {"data_validade": "A validade deve ser posterior à data da compra."}
    if d["data_compra"] > datetime.now().date():
        return {"data_compra": "A data da compra não pode estar no futuro."}
    return {}


def registrar_compra(sessao, dados):
    sessao.exigir("insumos", editar=True)
    d = validar_ou_falhar(dados, CAMPOS_COMPRA, _validade_depois)
    with banco():
        return repo.inserir_compra(d)


def registrar_consumo_avulso(sessao, dados, agora=None):
    """Consumo sem atendimento (perda, descarte); exige motivo."""
    sessao.exigir("insumos", editar=True)
    d = validar_ou_falhar(dados, CAMPOS_CONSUMO)
    with banco():
        saldo = repo.saldo(d["id_insumo"])
    conferir_saldo([(d["id_insumo"], d["quantidade"])],
                   {d["id_insumo"]: dict(saldo=saldo or 0, nome_insumo=dados.get("nome_insumo",
                                                                                 "Insumo"),
                                         unidade_medida=dados.get("unidade_medida", ""))})
    with banco():
        return repo.inserir_consumo_avulso(d["id_insumo"], d["quantidade"],
                                           agora or datetime.now(), d["observacao"])
