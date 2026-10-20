"""Acesso por perfil: 'ler' ou 'editar'. Módulo ausente = sem acesso."""
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
        "insumos": EDITAR,
        "procedimentos": EDITAR,
        "unidades": LER,
    },
    PROFISSIONAL: {
        "inicio": LER,
        "pacientes": EDITAR,
        "atendimentos": EDITAR,
        "anamnese": EDITAR,
    },
}
# suposição: a Atendente não vê a anamnese (não constava no perfil dela)


def nivel(perfil, modulo):
    return ACESSO.get(perfil, {}).get(modulo)


def pode_ver(perfil, modulo):
    return nivel(perfil, modulo) is not None


def pode_editar(perfil, modulo):
    return nivel(perfil, modulo) == EDITAR


def modulos_visiveis(perfil):
    return [m for m in MODULOS if pode_ver(perfil, m)]
