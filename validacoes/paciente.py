from datetime import date
from validacoes.documentos import validar_cpf, validar_cep, validar_telefone

CAMPOS_OBRIGATORIOS = {
    "nome_completo": "Nome completo",
    "cpf": "CPF",
    "data_nasc": "Data de nascimento",
    "telefone_paciente": "Telefone",
    "cep_paciente": "CEP",
    "endereco_paciente": "Endereço",
    "bairro_paciente": "Bairro",
    "cidade_paciente": "Cidade",
    "origem_captacao": "Origem da captação",
}


def validar_paciente(dados):
    """Retorna uma lista de mensagens de erro. Lista vazia = dados válidos."""
    erros = []

    for campo, rotulo in CAMPOS_OBRIGATORIOS.items():
        valor = dados.get(campo)
        if valor is None or str(valor).strip() == "":
            erros.append(f"{rotulo} é obrigatório.")

    if erros:
        return erros  # sem os campos básicos, não adianta validar o formato

    if not validar_cpf(dados["cpf"]):
        erros.append("CPF inválido.")
    if not validar_telefone(dados["telefone_paciente"]):
        erros.append("Telefone inválido. Informe DDD + número.")
    if not validar_cep(dados["cep_paciente"]):
        erros.append("CEP inválido. Informe 8 dígitos.")

    nasc = dados["data_nasc"]
    if not isinstance(nasc, date):
        erros.append("Data de nascimento inválida.")
    elif nasc >= date.today():
        erros.append("Data de nascimento deve ser anterior a hoje.")

    email = (dados.get("email_paciente") or "").strip()
    if email and ("@" not in email or "." not in email.split("@")[-1]):
        erros.append("E-mail inválido.")

    return erros
