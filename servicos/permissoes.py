"""Quem acessa o quê, por perfil. Única fonte da regra: o menu, as telas e
os serviços consultam este módulo.

Níveis: "ler" (consulta) ou "editar" (consulta, inclusão, alteração e
inativação). Módulo ausente = sem acesso (o menu esconde).
"""
GERENTE, ATENDENTE, PROFISSIONAL = "Gerente", "Atendente", "Profissional"
PERFIS = (GERENTE, ATENDENTE, PROFISSIONAL)

LER, EDITAR = "ler", "editar"

MODULOS = ("inicio", "pacientes", "anamnese", "atendimentos", "procedimentos",
           "unidades", "insumos", "financeiro", "dashboard")

ACESSO = {
    GERENTE: {m: EDITAR for m in MODULOS},
    ATENDENTE: {
        "inicio": LER,
        "pacientes": EDITAR,
        "atendimentos": EDITAR,
        "insumos": EDITAR,          # inclui fornecedores, compras e consumo avulso
        "procedimentos": EDITAR,
        "unidades": LER,            # só leitura
    },
    PROFISSIONAL: {
        "inicio": LER,
        "pacientes": EDITAR,
        "atendimentos": EDITAR,
        "anamnese": EDITAR,
    },
}
# SUPOSIÇÃO: a anamnese (dado de saúde) não aparece para a Atendente,
# porque não foi listada no perfil dela.


def nivel(perfil, modulo):
    return ACESSO.get(perfil, {}).get(modulo)


def pode_ver(perfil, modulo):
    return nivel(perfil, modulo) is not None


def pode_editar(perfil, modulo):
    return nivel(perfil, modulo) == EDITAR


def modulos_visiveis(perfil):
    return [m for m in MODULOS if pode_ver(perfil, m)]
