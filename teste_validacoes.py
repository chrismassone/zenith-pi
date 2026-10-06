from validacoes.documentos import validar_cpf, validar_cep, validar_telefone, somente_digitos

casos = [
    ("CPF válido (formatado)",   validar_cpf("529.982.247-25"), True),
    ("CPF válido (só números)",  validar_cpf("52998224725"),    True),
    ("CPF dígito errado",        validar_cpf("52998224726"),    False),
    ("CPF repetido",             validar_cpf("11111111111"),    False),
    ("CPF curto",                validar_cpf("1234567"),        False),
    ("CPF vazio",                validar_cpf(""),               False),
    ("CPF None",                 validar_cpf(None),             False),
    ("CEP válido com zero",      validar_cep("03047-000"),      True),
    ("CEP curto",                validar_cep("0304700"),        False),
    ("Celular válido",           validar_telefone("(11) 98765-4321"), True),
    ("Fixo válido",              validar_telefone("1133334444"),      True),
    ("Celular sem o 9",          validar_telefone("11887654321"),     False),
    ("DDD começando com 0",      validar_telefone("0198765432"),      False),
    ("Telefone curto",           validar_telefone("98765432"),        False),
    ("Zero à esquerda preservado", somente_digitos("03047-000"), "03047000"),
]

falhas = 0
for nome, obtido, esperado in casos:
    ok = obtido == esperado
    falhas += not ok
    print(("OK   " if ok else "FALHA"), nome, "" if ok else f"(obtido {obtido!r})")
print(f"\n{len(casos) - falhas}/{len(casos)} testes passaram")
