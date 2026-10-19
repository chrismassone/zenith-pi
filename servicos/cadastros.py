"""Regras dos cadastros simples: unidades, fornecedores, procedimentos
(com a lista de insumos padrão) e insumos."""
from repositorios import cadastros as repo
from servicos.base import banco
from servicos.erros import DadosInvalidos
from servicos.validador import Campo, validar, validar_ou_falhar

# ---------- unidades ----------
CAMPOS_UNIDADE = [
    Campo("nome_clinica", "Nome da unidade", maximo=50),
    Campo("bairro_unidade", "Bairro", maximo=40),
    Campo("cidade_unidade", "Cidade", maximo=40),
    Campo("uf_unidade", "UF", "uf"),
    # SUPOSIÇÃO: valor por dia de uso da sala (ver vw_dash_unidade)
    Campo("valor_locacao", "Valor de locação por dia", "decimal", minimo=0),
]


def listar_unidades(sessao, busca="", incluir_inativos=False):
    sessao.exigir("unidades")
    with banco():
        return repo.listar_unidades(busca, incluir_inativos)


def unidades_ativas(sessao):
    """Para os filtros e seletores de outras telas (não exige o módulo Unidades)."""
    sessao.tocar()
    with banco():
        return repo.listar_unidades()


def salvar_unidade(sessao, dados, id_=None):
    sessao.exigir("unidades", editar=True)
    d = validar_ou_falhar(dados, CAMPOS_UNIDADE)
    with banco({"uq_unidade_nome": ("nome_clinica", "Já existe uma unidade com este nome.")}):
        if id_ is None:
            return repo.inserir_unidade(d)
        repo.atualizar_unidade(id_, d)
        return id_


def ativar_unidade(sessao, id_, ativo):
    sessao.exigir("unidades", editar=True)
    with banco():
        repo.ativar_unidade(id_, ativo)


# ---------- fornecedores ----------
CAMPOS_FORNECEDOR = [
    Campo("razao_social", "Razão social", maximo=100),
    Campo("cnpj", "CNPJ", "cnpj"),
    Campo("telefone_fornecedor", "Telefone", "telefone"),
    Campo("cep_fornecedor", "CEP", "cep"),
    Campo("endereco_fornecedor", "Endereço", maximo=100),
    Campo("bairro_fornecedor", "Bairro", maximo=40),
    Campo("cidade_fornecedor", "Cidade", maximo=40),
]


def listar_fornecedores(sessao, busca="", incluir_inativos=False):
    sessao.exigir("insumos")
    with banco():
        return repo.listar_fornecedores(busca, incluir_inativos)


def salvar_fornecedor(sessao, dados, id_=None):
    sessao.exigir("insumos", editar=True)
    d = validar_ou_falhar(dados, CAMPOS_FORNECEDOR)
    with banco({"uq_fornecedor_cnpj": ("cnpj", "Já existe um fornecedor com este CNPJ.")}):
        if id_ is None:
            return repo.inserir_fornecedor(d)
        repo.atualizar_fornecedor(id_, d)
        return id_


def ativar_fornecedor(sessao, id_, ativo):
    sessao.exigir("insumos", editar=True)
    with banco():
        repo.ativar_fornecedor(id_, ativo)


# ---------- procedimentos ----------
CAMPOS_PROCEDIMENTO = [
    Campo("nome_procedimento", "Nome do procedimento", maximo=60),
    Campo("preco_tabela", "Preço de tabela", "decimal", minimo=0),
    Campo("intervalo_retorno_dias", "Intervalo de retorno (dias)", "inteiro",
          obrigatorio=False, maior_que_zero=True),
]
AVISO_PADRAO = ("As quantidades padrão são sugestões. Alterá-las não muda os "
                "consumos já registrados.")


def listar_procedimentos(sessao, busca="", incluir_inativos=False):
    sessao.exigir("procedimentos")
    with banco():
        return repo.listar_procedimentos(busca, incluir_inativos)


def procedimentos_ativos(sessao):
    sessao.tocar()
    with banco():
        return repo.listar_procedimentos()


def insumos_do_procedimento(sessao, id_procedimento):
    sessao.exigir("procedimentos")
    with banco():
        return repo.insumos_do_procedimento(id_procedimento)


def validar_lista_insumos(linhas):
    """linhas = [{'id_insumo': ..., 'quantidade_padrao': texto}] -> [(id, Decimal)].
    Erros vão na chave 'insumos'."""
    resultado, vistos = [], set()
    for n, linha in enumerate(linhas, start=1):
        if not linha.get("id_insumo") and not str(linha.get("quantidade_padrao") or "").strip():
            continue                                    # linha em branco: ignora
        limpos, erros = validar(linha, [
            Campo("id_insumo", "Insumo", "id"),
            Campo("quantidade_padrao", "Quantidade padrão", "decimal", maior_que_zero=True)])
        if erros:
            raise DadosInvalidos({"insumos": f"Linha {n}: " + " ".join(erros.values())})
        if limpos["id_insumo"] in vistos:
            raise DadosInvalidos({"insumos": f"Linha {n}: insumo repetido na lista."})
        vistos.add(limpos["id_insumo"])
        resultado.append((limpos["id_insumo"], limpos["quantidade_padrao"]))
    return resultado


def salvar_procedimento(sessao, dados, linhas_insumos, id_=None):
    sessao.exigir("procedimentos", editar=True)
    d = validar_ou_falhar(dados, CAMPOS_PROCEDIMENTO)
    insumos = validar_lista_insumos(linhas_insumos)
    dup = {"uq_procedimento_nome": ("nome_procedimento",
                                    "Já existe um procedimento com este nome.")}
    with banco(dup):
        return repo.salvar_procedimento(id_, d, insumos)


def ativar_procedimento(sessao, id_, ativo):
    sessao.exigir("procedimentos", editar=True)
    with banco():
        repo.ativar_procedimento(id_, ativo)


# ---------- insumos (cadastro) ----------
UNIDADES_MEDIDA = ["U", "mL", "g", "un", "par", "frasco", "seringa"]
CAMPOS_INSUMO = [
    Campo("nome_insumo", "Nome do insumo", maximo=60),
    Campo("marca", "Marca", maximo=40),
    Campo("apresentacao", "Apresentação", maximo=40),
    Campo("unidade_medida", "Unidade de medida", maximo=10),
    Campo("estoque_minimo", "Estoque mínimo", "decimal", minimo=0),
]


def listar_insumos(sessao, busca="", incluir_inativos=False):
    sessao.exigir("insumos")
    with banco():
        return repo.listar_insumos(busca, incluir_inativos)


def insumos_ativos(sessao):
    sessao.tocar()
    with banco():
        return repo.listar_insumos()


def salvar_insumo(sessao, dados, id_=None):
    sessao.exigir("insumos", editar=True)
    d = validar_ou_falhar(dados, CAMPOS_INSUMO)
    dup = {"uq_insumo": ("nome_insumo",
                         "Já existe um insumo com este nome, marca e apresentação.")}
    with banco(dup):
        if id_ is None:
            return repo.inserir_insumo(d)
        repo.atualizar_insumo(id_, d)
        return id_


def ativar_insumo(sessao, id_, ativo):
    sessao.exigir("insumos", editar=True)
    with banco():
        repo.ativar_insumo(id_, ativo)


def profissionais(sessao):
    sessao.tocar()
    with banco():
        return repo.listar_profissionais()
