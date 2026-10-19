"""Conversão de textos digitados (data, hora, dinheiro, quantidade).
Funções puras: devolvem None quando o texto não é válido."""
from datetime import date, datetime, time
from decimal import Decimal, InvalidOperation
import re


def converter_data(texto):
    """'dd/mm/aaaa' (ou 'ddmmaaaa') -> date. date já pronta passa direto."""
    if isinstance(texto, date):
        return texto
    texto = (texto or "").strip()
    if re.fullmatch(r"\d{8}", texto):
        texto = f"{texto[:2]}/{texto[2:4]}/{texto[4:]}"
    if not re.fullmatch(r"\d{2}/\d{2}/\d{4}", texto):
        return None
    try:
        return datetime.strptime(texto, "%d/%m/%Y").date()
    except ValueError:      # ex.: 31/02/2000
        return None


def converter_hora(texto):
    """'hh:mm' (ou 'hhmm') -> time."""
    if isinstance(texto, time):
        return texto
    texto = (texto or "").strip()
    if re.fullmatch(r"\d{4}", texto):
        texto = f"{texto[:2]}:{texto[2:]}"
    if not re.fullmatch(r"\d{1,2}:\d{2}", texto):
        return None
    h, m = map(int, texto.split(":"))
    return time(h, m) if h < 24 and m < 60 else None


def converter_decimal(texto, casas=2):
    """'1.234,56', '1234,56', '1234.56' ou número -> Decimal. None se inválido."""
    if isinstance(texto, (int, float, Decimal)):
        valor = Decimal(str(texto))
    else:
        texto = (texto or "").strip().replace("R$", "").replace(" ", "")
        if not texto:
            return None
        if "," in texto:                       # padrão brasileiro
            texto = texto.replace(".", "").replace(",", ".")
        if not re.fullmatch(r"-?\d+(\.\d+)?", texto):
            return None
        try:
            valor = Decimal(texto)
        except InvalidOperation:
            return None
    return valor.quantize(Decimal(1).scaleb(-casas))


def converter_inteiro(texto):
    if isinstance(texto, int):
        return texto
    texto = (texto or "").strip()
    return int(texto) if re.fullmatch(r"\d+", texto) else None
