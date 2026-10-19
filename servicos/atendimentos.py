"""Regras de atendimentos: itens, valor, situação e o consumo de insumos
registrado quando o atendimento é marcado como Realizado.

Fluxo para marcar Realizado:
  1. sugerir_consumo() devolve os insumos padrão dos procedimentos, com a
     quantidade SUGERIDA e o saldo de cada um;
  2. a profissional ajusta as quantidades na tela;
  3. salvar(..., consumos=[(id_insumo, quantidade_final)]) grava tudo numa
     transação e recusa qualquer quantidade acima do saldo.
"""
from collections import OrderedDict
from datetime import datetime
from decimal import Decimal

from repositorios import atendimento as repo
from servicos.base import banco
from servicos.erros import DadosInvalidos, NaoEncontrado, SaldoInsuficiente
from servicos.validador import Campo, validar, validar_ou_falhar
from validacoes.valores import converter_decimal

STATUS = ("Agendado", "Realizado", "Cancelado", "Faltou")
PAGAMENTOS = ("Pix", "Cartão de crédito", "Cartão de débito", "Dinheiro")

CAMPOS = [
    Campo("id_paciente", "Paciente", "id"),
    Campo("id_profissional", "Profissional", "id"),
    Campo("id_unidade", "Unidade", "id"),
    Campo("data", "Data", "data"),
    Campo("hora", "Hora", "hora"),
    Campo("status", "Situação", "escolha", opcoes=STATUS),
    Campo("forma_pagamento", "Forma de pagamento", "escolha", obrigatorio=False,
          opcoes=PAGAMENTOS),
    Campo("desconto", "Desconto", "decimal", obrigatorio=False, minimo=0),
    Campo("observacao", "Observação", obrigatorio=False, maximo=255),
]
CAMPOS_ITEM = [
    Campo("id_procedimento", "Procedimento", "id"),
    Campo("regiao_aplicada", "Região de aplicação", maximo=30),
    Campo("quantidade_aplicada", "Quantidade", "decimal", maior_que_zero=True),
    Campo("valor_cobrado", "Valor cobrado", "decimal", minimo=0),
]


# ---------------- lógica pura (testável sem banco) ----------------
def validar_itens(linhas):
    """Linhas em branco são ignoradas; linhas incompletas geram erro na chave 'itens'."""
    itens = []
    for n, linha in enumerate(linhas, start=1):
        if not any(str(linha.get(c.chave) or "").strip() for c in CAMPOS_ITEM):
            continue
        limpos, erros = validar(linha, CAMPOS_ITEM)
        if erros:
            raise DadosInvalidos({"itens": f"Procedimento {n}: " + " ".join(erros.values())})
        itens.append(limpos)
    return itens


def subtotal(itens):
    return sum((i["valor_cobrado"] for i in itens), Decimal("0.00"))


def total(itens, desconto):
    """Mesma regra da view vw_valor_atendimento: itens - desconto, nunca negativo."""
    return max(subtotal(itens) - (desconto or Decimal("0")), Decimal("0.00"))


def regras_cabecalho(d, itens, agora):
    erros = {}
    if d["status"] in ("Agendado", "Realizado") and not itens:
        erros["itens"] = "Inclua ao menos um procedimento."
    # SUPOSIÇÃO: atendimento realizado precisa ter a forma de pagamento informada
    if d["status"] == "Realizado" and not d["forma_pagamento"]:
        erros["forma_pagamento"] = "Informe a forma de pagamento do atendimento realizado."
    if d["status"] in ("Realizado", "Faltou") and d["data_hora"] > agora:
        erros["data"] = f"Um atendimento futuro não pode ser marcado como {d['status']}."
    if d["desconto"] and d["desconto"] > subtotal(itens):
        erros["desconto"] = "O desconto não pode ser maior que o valor dos procedimentos."
    return erros


def agregar_sugestoes(linhas_sugestao, ids_procedimento):
    """Soma a quantidade padrão por insumo, uma vez por procedimento incluído
    (o mesmo procedimento duas vezes conta duas vezes). Devolve a lista na
    ordem do nome do insumo, com saldo e quantidade sugerida."""
    vezes = {}
    for pid in ids_procedimento:
        vezes[pid] = vezes.get(pid, 0) + 1
    por_insumo = OrderedDict()
    for s in linhas_sugestao:
        item = por_insumo.setdefault(s["id_insumo"], dict(
            id_insumo=s["id_insumo"], nome_insumo=s["nome_insumo"], marca=s["marca"],
            unidade_medida=s["unidade_medida"], saldo=s["saldo"],
            quantidade_sugerida=Decimal("0.00")))
        item["quantidade_sugerida"] += s["quantidade_padrao"] * vezes.get(s["id_procedimento"], 0)
    return list(por_insumo.values())


def validar_consumos(linhas):
    """linhas = [{'id_insumo', 'quantidade' (texto)}] -> [(id, Decimal)] sem
    as quantidades zero (insumo não usado)."""
    resultado = {}
    for linha in linhas:
        qtd = converter_decimal(linha.get("quantidade"))
        nome = linha.get("nome_insumo", "insumo")
        if qtd is None or qtd < 0:
            raise DadosInvalidos({"consumo": f"Quantidade inválida para {nome}."})
        if qtd > 0:
            resultado[linha["id_insumo"]] = resultado.get(linha["id_insumo"], 0) + qtd
    return list(resultado.items())


def conferir_saldo(consumos, saldos):
    """Recusa (SaldoInsuficiente) se alguma quantidade passar do saldo."""
    faltas = []
    for id_insumo, qtd in consumos:
        s = saldos.get(id_insumo)
        disponivel = s["saldo"] if s else Decimal("0")
        if qtd > disponivel:
            nome = s["nome_insumo"] if s else f"insumo {id_insumo}"
            un = s["unidade_medida"] if s else ""
            faltas.append(f"{nome}: disponível {fmt(disponivel)} {un}, "
                          f"informado {fmt(qtd)} {un}.")
    if faltas:
        raise SaldoInsuficiente("Saldo insuficiente em estoque. " + " ".join(faltas)
                                + " Registre a compra ou ajuste a quantidade.")


def fmt(n):
    texto = f"{Decimal(n):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return texto[:-3] if texto.endswith(",00") else texto


# ---------------- serviços ----------------
def listar(sessao, busca="", id_unidade=None, status=None, data_ini=None, data_fim=None):
    sessao.exigir("atendimentos")
    with banco():
        return repo.listar(busca, id_unidade, status, data_ini, data_fim)


def obter(sessao, id_atendimento):
    sessao.exigir("atendimentos")
    with banco():
        a = repo.buscar(id_atendimento)
    if not a:
        raise NaoEncontrado("Atendimento não encontrado.")
    return a


def precisa_registrar_consumo(sessao, status, id_atendimento=None):
    """True quando salvar como Realizado vai registrar consumo de insumos
    (atendimento ainda sem consumo registrado)."""
    if status != "Realizado":
        return False
    if id_atendimento is None:
        return True
    return obter(sessao, id_atendimento)["qtd_consumos"] == 0


def sugerir_consumo(sessao, linhas_itens):
    sessao.exigir("atendimentos", editar=True)
    itens = validar_itens(linhas_itens)
    ids = [i["id_procedimento"] for i in itens]
    with banco():
        return agregar_sugestoes(repo.sugestao_insumos(sorted(set(ids))), ids)


def salvar(sessao, dados, linhas_itens, consumos=None, id_atendimento=None,
           agora=None):
    """Grava o atendimento. 'consumos' (lista de dicionários da tela de
    confirmação) é obrigatório quando o atendimento passa a Realizado."""
    sessao.exigir("atendimentos", editar=True)
    agora = agora or datetime.now()
    d = validar_ou_falhar(dados, CAMPOS)
    itens = validar_itens(linhas_itens)
    d["data_hora"] = datetime.combine(d.pop("data"), d.pop("hora"))
    d["desconto"] = d["desconto"] or Decimal("0.00")
    if d["status"] != "Realizado":
        d["forma_pagamento"] = None
    erros = regras_cabecalho(d, itens, agora)
    if erros:
        raise DadosInvalidos(erros)

    registrar = False
    if id_atendimento is not None:
        anterior = obter(sessao, id_atendimento)
        if anterior["status"] == "Realizado" and d["status"] != "Realizado":
            raise DadosInvalidos({"status": "Um atendimento realizado não pode mudar de "
                                            "situação: o consumo de insumos já foi registrado."})
        registrar = d["status"] == "Realizado" and anterior["qtd_consumos"] == 0
    else:
        registrar = d["status"] == "Realizado"

    lista_consumo = []
    if registrar:
        if consumos is None:
            raise DadosInvalidos({None: "Confirme os insumos usados antes de salvar."})
        lista_consumo = validar_consumos(consumos)
        with banco():
            saldos = repo.saldos([i for i, _ in lista_consumo])
        conferir_saldo(lista_consumo, saldos)

    with banco():
        return repo.salvar(id_atendimento, d, itens, lista_consumo)
