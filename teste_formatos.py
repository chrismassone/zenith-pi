from datetime import date, datetime, time
from decimal import Decimal

from interface.formatos import (brl, formatar_cep, formatar_cnpj, formatar_cpf,
                                formatar_data, formatar_data_hora, formatar_telefone,
                                mes_curto, mes_extenso, numero, percentual)
from validacoes.valores import (converter_data, converter_decimal, converter_hora,
                                converter_inteiro)

casos = [
    ("CPF formatado",               formatar_cpf("52998224725"), "529.982.247-25"),
    ("CPF já formatado",            formatar_cpf("529.982.247-25"), "529.982.247-25"),
    ("CPF fora do padrão intacto",  formatar_cpf("123"), "123"),
    ("CPF None",                    formatar_cpf(None), ""),
    ("CNPJ formatado",              formatar_cnpj("11222333000181"), "11.222.333/0001-81"),
    ("Celular formatado",           formatar_telefone("11987654321"), "(11) 98765-4321"),
    ("Fixo formatado",              formatar_telefone("1133334444"), "(11) 3333-4444"),
    ("Telefone fora do padrão",     formatar_telefone("9876"), "9876"),
    ("CEP com zero à esquerda",     formatar_cep("03047000"), "03047-000"),
    ("Data para texto",             formatar_data(date(1990, 5, 10)), "10/05/1990"),
    ("Data None para texto",        formatar_data(None), ""),
    ("Data e hora",                 formatar_data_hora(datetime(2026, 10, 16, 9, 5)),
                                    "16/10/2026 09:05"),
    ("Converte dd/mm/aaaa",         converter_data("10/05/1990"), date(1990, 5, 10)),
    ("Converte só dígitos",         converter_data("10051990"), date(1990, 5, 10)),
    ("Converte com espaços",        converter_data(" 01/01/2000 "), date(2000, 1, 1)),
    ("Recusa 31/02",                converter_data("31/02/2000"), None),
    ("Recusa formato aaaa-mm-dd",   converter_data("1990-05-10"), None),
    ("Recusa ano curto",            converter_data("10/05/90"), None),
    ("Recusa vazio",                converter_data(""), None),
    ("Hora hh:mm",                  converter_hora("09:30"), time(9, 30)),
    ("Hora sem dois-pontos",        converter_hora("1415"), time(14, 15)),
    ("Recusa hora 25:00",           converter_hora("25:00"), None),
    ("Dinheiro brasileiro",         converter_decimal("1.234,56"), Decimal("1234.56")),
    ("Dinheiro com ponto decimal",  converter_decimal("1234.5"), Decimal("1234.50")),
    ("Dinheiro com R$",             converter_decimal("R$ 90,00"), Decimal("90.00")),
    ("Recusa texto como número",    converter_decimal("abc"), None),
    ("Inteiro",                     converter_inteiro("150"), 150),
    ("Recusa inteiro com vírgula",  converter_inteiro("1,5"), None),
    ("R$ com milhar",               brl(Decimal("1234.5")), "R$ 1.234,50"),
    ("R$ negativo",                 brl(Decimal("-50")), "-R$ 50,00"),
    ("R$ vazio",                    brl(None), "—"),
    ("Número inteiro sem ,00",      numero(Decimal("50.00")), "50"),
    ("Número com casas",            numero(Decimal("2.5")), "2,50"),
    ("Percentual",                  percentual(Decimal("0.9071")), "90,7%"),
    ("Percentual vazio",            percentual(None), "—"),
    ("Mês por extenso",             mes_extenso("2026-09"), "Setembro de 2026"),
    ("Mês curto",                   mes_curto("2026-03"), "mar/26"),
]

falhas = 0
for nome, obtido, esperado in casos:
    ok = obtido == esperado
    falhas += not ok
    print(("OK   " if ok else "FALHA"), nome, "" if ok else f"(obtido {obtido!r})")
print(f"\n{len(casos) - falhas}/{len(casos)} testes passaram")
