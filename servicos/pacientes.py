"""Pacientes, anamnese e histórico."""
from datetime import date

from repositorios import paciente as repo
from servicos.base import banco
from servicos.erros import AcessoNegado, NaoEncontrado
from servicos.validador import Campo, validar_ou_falhar

ORIGENS_SUGERIDAS = ["Instagram", "Indicação"]

CAMPOS = [
    Campo("nome_completo", "Nome completo", maximo=100),
    Campo("cpf", "CPF", "cpf"),
    Campo("data_nasc", "Data de nascimento", "data"),
    Campo("telefone_paciente", "Telefone", "telefone"),
    Campo("email_paciente", "E-mail", "email", obrigatorio=False, maximo=100),
    Campo("cep_paciente", "CEP", "cep"),
    Campo("endereco_paciente", "Endereço", maximo=100),
    Campo("bairro_paciente", "Bairro", maximo=40),
    Campo("cidade_paciente", "Cidade", maximo=40),
    Campo("origem_captacao", "Origem da captação", maximo=30),
]
DUPLICADOS = {"uq_paciente_cpf": ("cpf", "Já existe um paciente com este CPF.")}

CAMPOS_ANAMNESE = [
    Campo("queixa_principal", "Queixa principal", maximo=500),
    Campo("historico_saude", "Histórico de saúde", obrigatorio=False, maximo=5000),
    Campo("alergias", "Alergias", obrigatorio=False, maximo=500),
    Campo("medicamentos_em_uso", "Medicamentos em uso", obrigatorio=False, maximo=500),
    Campo("observacoes", "Observações", obrigatorio=False, maximo=5000),
]


def _data_futura(d):
    if d["data_nasc"] and d["data_nasc"] >= date.today():
        return {"data_nasc": "A data de nascimento deve ser anterior a hoje."}
    return {}


def listar(sessao, busca="", incluir_inativos=False):
    sessao.exigir("pacientes")
    with banco():
        return repo.listar(busca, incluir_inativos)


def obter(sessao, id_paciente):
    sessao.exigir("pacientes")
    with banco():
        p = repo.buscar_por_id(id_paciente)
    if not p:
        raise NaoEncontrado("Paciente não encontrado.")
    return p


def salvar(sessao, dados, id_paciente=None):
    sessao.exigir("pacientes", editar=True)
    d = validar_ou_falhar(dados, CAMPOS, _data_futura)
    with banco(DUPLICADOS):
        if id_paciente is None:
            return repo.inserir(d)
        repo.atualizar(id_paciente, d)
        return id_paciente


def definir_ativo(sessao, id_paciente, ativo):
    """Pacientes não são excluídos, só inativados."""
    sessao.exigir("pacientes", editar=True)
    with banco():
        repo.definir_ativo(id_paciente, ativo)


# anamnese
def listar_anamneses(sessao, id_paciente):
    sessao.exigir("anamnese")
    with banco():
        return repo.listar_anamneses(id_paciente)


def salvar_anamnese(sessao, id_paciente, dados, id_anamnese=None, id_profissional=None):
    """Registra com a profissional da sessão ou a informada (Gerente)."""
    sessao.exigir("anamnese", editar=True)
    d = validar_ou_falhar(dados, CAMPOS_ANAMNESE)
    with banco():
        if id_anamnese is not None:
            repo.atualizar_anamnese(id_anamnese, d)
            return id_anamnese
        prof = sessao.id_profissional or id_profissional
        if not prof:
            raise AcessoNegado("Informe a profissional responsável pela anamnese.")
        return repo.inserir_anamnese(id_paciente, prof, d)


# histórico
def historico(sessao, id_paciente):
    sessao.exigir("pacientes")
    with banco():
        return repo.historico(id_paciente)
