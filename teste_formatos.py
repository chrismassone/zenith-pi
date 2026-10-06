from datetime import date
from interface.formatos import (formatar_cpf, formatar_telefone, formatar_cep,
                                formatar_data, converter_data, montar_dados,
                                distribuir_erros)

# Formulário fictício e válido, usado como base dos casos abaixo
base = {
    "nome_completo": "Paciente Ficticio", "cpf": "529.982.247-25",
    "data_nasc": "10/05/1990", "telefone_paciente": "(11) 98765-4321",
    "email_paciente": "", "cep_paciente": "03047-000",
    "endereco_paciente": "Rua de Teste, 10", "bairro_paciente": "Mooca",
    "cidade_paciente": "Sao Paulo", "origem_captacao": "Instagram",
}
dados_ok, erros_ok = montar_dados(base)
_, erros_nome = montar_dados({**base, "nome_completo": "A" * 101})
_, erros_bairro = montar_dados({**base, "bairro_paciente": "B" * 41})
_, erros_origem = montar_dados({**base, "origem_captacao": "C" * 31})
dados_data_ruim, erros_data_ruim = montar_dados({**base, "data_nasc": "31/02/2000"})
dados_vazio, erros_vazio = montar_dados({**base, "data_nasc": ""})
por_campo, gerais = distribuir_erros(["CPF inválido.", "Já existe um paciente com este CPF.",
                                      "CEP inválido. Informe 8 dígitos.",
                                      "Data de nascimento é obrigatório.",
                                      "Mensagem sem campo."])

casos = [
    ("CPF formatado",               formatar_cpf("52998224725"), "529.982.247-25"),
    ("CPF já formatado",            formatar_cpf("529.982.247-25"), "529.982.247-25"),
    ("CPF fora do padrão intacto",  formatar_cpf("123"), "123"),
    ("CPF None",                    formatar_cpf(None), ""),
    ("Celular formatado",           formatar_telefone("11987654321"), "(11) 98765-4321"),
    ("Fixo formatado",              formatar_telefone("1133334444"), "(11) 3333-4444"),
    ("Telefone fora do padrão",     formatar_telefone("9876"), "9876"),
    ("CEP com zero à esquerda",     formatar_cep("03047000"), "03047-000"),
    ("Data para texto",             formatar_data(date(1990, 5, 10)), "10/05/1990"),
    ("Data None para texto",        formatar_data(None), ""),
    ("Converte dd/mm/aaaa",         converter_data("10/05/1990"), date(1990, 5, 10)),
    ("Converte só dígitos",         converter_data("10051990"), date(1990, 5, 10)),
    ("Converte com espaços",        converter_data(" 01/01/2000 "), date(2000, 1, 1)),
    ("Recusa 31/02",                converter_data("31/02/2000"), None),
    ("Recusa formato aaaa-mm-dd",   converter_data("1990-05-10"), None),
    ("Recusa ano curto",            converter_data("10/05/90"), None),
    ("Recusa vazio",                converter_data(""), None),
    ("Formulário válido sem erros", erros_ok, {}),
    ("Data convertida no envio",    dados_ok["data_nasc"], date(1990, 5, 10)),
    ("Nome com 101 caracteres",     list(erros_nome), ["nome_completo"]),
    ("Bairro com 41 caracteres",    list(erros_bairro), ["bairro_paciente"]),
    ("Origem com 31 caracteres",    list(erros_origem), ["origem_captacao"]),
    ("Data inexistente acusada",    list(erros_data_ruim), ["data_nasc"]),
    ("Data inexistente vira None",  dados_data_ruim["data_nasc"], None),
    ("Data vazia fica p/ repositório", (erros_vazio, dados_vazio["data_nasc"]), ({}, None)),
    ("Erro de CPF vai ao campo",    por_campo.get("cpf"), "CPF inválido."),
    ("Erro de CEP vai ao campo",    por_campo.get("cep_paciente"), "CEP inválido. Informe 8 dígitos."),
    ("Erro de data vai ao campo",   "data_nasc" in por_campo, True),
    ("Sobra vira mensagem geral",   gerais, ["Já existe um paciente com este CPF.",
                                             "Mensagem sem campo."]),
]

falhas = 0
for nome, obtido, esperado in casos:
    ok = obtido == esperado
    falhas += not ok
    print(("OK   " if ok else "FALHA"), nome, "" if ok else f"(obtido {obtido!r})")
print(f"\n{len(casos) - falhas}/{len(casos)} testes passaram")
