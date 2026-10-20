"""Formatação de valores para exibição."""
from datetime import date, datetime
from decimal import Decimal
import re

from validacoes.valores import converter_data  # noqa: F401

MESES = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto",
         "setembro", "outubro", "novembro", "dezembro"]


def _digitos(texto):
    return re.sub(r"\D", "", texto or "")


def formatar_cpf(cpf):
    d = _digitos(cpf)
    if len(d) != 11:
        return cpf or ""
    return f"{d[:3]}.{d[3:6]}.{d[6:9]}-{d[9:]}"


def formatar_cnpj(cnpj):
    d = _digitos(cnpj)
    if len(d) != 14:
        return cnpj or ""
    return f"{d[:2]}.{d[2:5]}.{d[5:8]}/{d[8:12]}-{d[12:]}"


def formatar_telefone(telefone):
    """Celular (11) 98765-4321 ou fixo (11) 3333-4444; fora do padrão, devolve como veio."""
    d = _digitos(telefone)
    if len(d) == 11:
        return f"({d[:2]}) {d[2:7]}-{d[7:]}"
    if len(d) == 10:
        return f"({d[:2]}) {d[2:6]}-{d[6:]}"
    return telefone or ""


def formatar_cep(cep):
    d = _digitos(cep)
    if len(d) != 8:
        return cep or ""
    return f"{d[:5]}-{d[5:]}"


def formatar_data(valor):
    return valor.strftime("%d/%m/%Y") if isinstance(valor, (date, datetime)) else ""


def formatar_data_hora(valor):
    return valor.strftime("%d/%m/%Y %H:%M") if isinstance(valor, datetime) else ""


def formatar_hora(valor):
    return valor.strftime("%H:%M") if valor else ""


def numero(valor, casas=2):
    """Formato brasileiro; inteiros sem ',00'."""
    if valor is None:
        return ""
    texto = f"{Decimal(valor):,.{casas}f}".replace(",", "X").replace(".", ",").replace("X", ".")
    if casas and texto.endswith("," + "0" * casas):
        texto = texto[:-(casas + 1)]
    return texto


def brl(valor):
    if valor is None:
        return "—"
    v = Decimal(valor)
    texto = f"{abs(v):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return f"-R$ {texto}" if v < 0 else f"R$ {texto}"


def percentual(razao, casas=1):
    if razao is None:
        return "—"
    return f"{Decimal(razao) * 100:.{casas}f}".replace(".", ",") + "%"


def mes_extenso(ano_mes):
    ano, mes = ano_mes.split("-")
    return f"{MESES[int(mes) - 1].capitalize()} de {ano}"


def mes_curto(ano_mes):
    ano, mes = ano_mes.split("-")
    return f"{MESES[int(mes) - 1][:3]}/{ano[2:]}"
