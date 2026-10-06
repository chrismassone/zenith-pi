import re


def somente_digitos(texto):
    """Remove tudo que não for número. Ex.: '123.456.789-09' -> '12345678909'."""
    return re.sub(r"\D", "", texto or "")


def validar_cpf(cpf):
    """Retorna True se o CPF tem 11 dígitos e os dígitos verificadores batem."""
    cpf = somente_digitos(cpf)

    if len(cpf) != 11:
        return False
    if cpf == cpf[0] * 11:  # 11111111111, 00000000000 etc. são inválidos
        return False

    for tamanho in (9, 10):
        soma = sum(int(cpf[i]) * (tamanho + 1 - i) for i in range(tamanho))
        digito = (soma * 10) % 11
        if digito == 10:
            digito = 0
        if digito != int(cpf[tamanho]):
            return False
    return True


def validar_cep(cep):
    """Retorna True se o CEP tem exatamente 8 dígitos."""
    return len(somente_digitos(cep)) == 8


def validar_telefone(telefone):
    """Retorna True para celular (11 dígitos) ou fixo (10 dígitos) com DDD."""
    digitos = somente_digitos(telefone)
    if len(digitos) not in (10, 11):
        return False
    if digitos[0] == "0" or digitos[1] == "0":  # DDD não começa com 0
        return False
    if len(digitos) == 11 and digitos[2] != "9":  # celular começa com 9
        return False
    return True
