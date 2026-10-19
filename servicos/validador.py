"""Validação declarativa dos dados de formulário.

Cada serviço descreve seus campos com Campo(...) e chama validar(), que
devolve os valores já convertidos e um dicionário de erros por campo.
"""
from dataclasses import dataclass, field
import re

from servicos.erros import DadosInvalidos, obrigatorio
from validacoes import documentos, valores


@dataclass
class Campo:
    chave: str
    rotulo: str
    tipo: str = "texto"      # texto, data, hora, decimal, inteiro, cpf, cnpj, cep,
                             # telefone, email, uf, escolha, id
    obrigatorio: bool = True
    maximo: int = None       # tamanho máximo (texto)
    minimo: object = None    # valor mínimo (decimal / inteiro)
    opcoes: tuple = field(default_factory=tuple)   # para tipo "escolha"
    maior_que_zero: bool = False


def _vazio(valor):
    return valor is None or (isinstance(valor, str) and not valor.strip())


def _converter(c, bruto):
    """Devolve (valor, mensagem_de_erro)."""
    if c.tipo == "texto":
        texto = str(bruto).strip()
        if c.maximo and len(texto) > c.maximo:
            return None, f"{c.rotulo}: máximo de {c.maximo} caracteres."
        return texto, None
    if c.tipo == "data":
        d = valores.converter_data(bruto)
        return (d, None) if d else (None, f"{c.rotulo} inválida. Use dd/mm/aaaa.")
    if c.tipo == "hora":
        h = valores.converter_hora(bruto)
        return (h, None) if h else (None, f"{c.rotulo} inválida. Use hh:mm.")
    if c.tipo in ("decimal", "inteiro"):
        n = (valores.converter_decimal(bruto) if c.tipo == "decimal"
             else valores.converter_inteiro(bruto))
        if n is None:
            return None, f"{c.rotulo}: informe um número válido."
        if c.maior_que_zero and n <= 0:
            return None, f"{c.rotulo}: informe um valor maior que zero."
        if c.minimo is not None and n < c.minimo:
            return None, f"{c.rotulo}: o valor mínimo é {c.minimo}."
        return n, None
    if c.tipo == "id":
        try:
            return int(bruto), None
        except (TypeError, ValueError):
            return None, obrigatorio(c.rotulo)
    if c.tipo == "cpf":
        d = documentos.somente_digitos(bruto)
        return (d, None) if documentos.validar_cpf(d) else (None, "CPF inválido.")
    if c.tipo == "cnpj":
        d = documentos.somente_digitos(bruto)
        return (d, None) if documentos.validar_cnpj(d) else (None, "CNPJ inválido.")
    if c.tipo == "cep":
        d = documentos.somente_digitos(bruto)
        return (d, None) if documentos.validar_cep(d) else (None, "CEP inválido. Informe 8 dígitos.")
    if c.tipo == "telefone":
        d = documentos.somente_digitos(bruto)
        return ((d, None) if documentos.validar_telefone(d)
                else (None, "Telefone inválido. Informe DDD + número."))
    if c.tipo == "email":
        texto = str(bruto).strip().lower()
        if c.maximo and len(texto) > c.maximo:
            return None, f"{c.rotulo}: máximo de {c.maximo} caracteres."
        ok = re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", texto)
        return (texto, None) if ok else (None, "E-mail inválido.")
    if c.tipo == "uf":
        texto = str(bruto).strip().upper()
        return ((texto, None) if re.fullmatch(r"[A-Z]{2}", texto)
                else (None, "Informe a UF com duas letras."))
    if c.tipo == "escolha":
        return (bruto, None) if bruto in c.opcoes else (None, f"{c.rotulo}: opção inválida.")
    raise ValueError(f"tipo de campo desconhecido: {c.tipo}")


def validar(dados, campos):
    """Devolve (limpos, erros). Campos opcionais vazios viram None."""
    limpos, erros = {}, {}
    for c in campos:
        bruto = dados.get(c.chave)
        if _vazio(bruto):
            limpos[c.chave] = None
            if c.obrigatorio:
                erros[c.chave] = obrigatorio(c.rotulo)
            continue
        valor, erro = _converter(c, bruto)
        if erro:
            erros[c.chave] = erro
        limpos[c.chave] = valor
    return limpos, erros


def validar_ou_falhar(dados, campos, extra=None):
    """Como validar(), mas levanta DadosInvalidos se houver qualquer erro.
    'extra' recebe os limpos e devolve erros adicionais {campo: mensagem}."""
    limpos, erros = validar(dados, campos)
    if extra and not erros:
        erros.update(extra(limpos) or {})
    if erros:
        raise DadosInvalidos(erros)
    return limpos
