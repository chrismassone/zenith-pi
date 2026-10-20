import re


def somente_digitos(texto):
    return re.sub(r"\D", "", texto or "")


def validar_cpf(cpf):
    cpf = somente_digitos(cpf)

    if len(cpf) != 11:
        return False
    if cpf == cpf[0] * 11:  # 111.111.111-11 passa no cálculo, mas é inválido
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
    return len(somente_digitos(cep)) == 8


def validar_telefone(telefone):
    """Celular (11 dígitos) ou fixo (10), com DDD."""
    digitos = somente_digitos(telefone)
    if len(digitos) not in (10, 11):
        return False
    if digitos[0] == "0" or digitos[1] == "0":  # DDD não começa com 0
        return False
    if len(digitos) == 11 and digitos[2] != "9":  # celular começa com 9
        return False
    return True


def validar_cnpj(cnpj):
    cnpj = somente_digitos(cnpj)
    if len(cnpj) != 14 or cnpj == cnpj[0] * 14:
        return False
    for pesos in ([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
                  [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]):
        resto = sum(int(d) * p for d, p in zip(cnpj, pesos)) % 11
        if int(cnpj[len(pesos)]) != (0 if resto < 2 else 11 - resto):
            return False
    return True
