"""Início, Financeiro e Dashboard. Todos os números vêm das views vw_* (as
mesmas do Power BI); aqui só se soma e se divide por cima delas."""
from datetime import date, timedelta
from decimal import Decimal

from repositorios import relatorios as repo
from servicos.base import banco
from servicos.validador import Campo, validar_ou_falhar

ZERO = Decimal("0.00")


def _razao(numerador, denominador):
    return (Decimal(numerador) / Decimal(denominador)) if denominador else None


# ---------- Início ----------
def inicio(sessao, hoje=None):
    sessao.exigir("inicio")
    hoje = hoje or date.today()
    fim_semana = hoje + timedelta(days=6 - hoje.weekday())   # até domingo
    with banco():
        r = repo.resumo_inicio(hoje, fim_semana)
        r["agenda"] = repo.agenda_do_dia(hoje)
    r["itens_em_alerta"] = r["abaixo_minimo"] + r["alerta_validade"]
    return r


# ---------- Financeiro ----------
def meses(sessao):
    sessao.tocar()
    with banco():
        return repo.meses_disponiveis()


def financeiro(sessao, ano_ini, ano_fim, id_unidade=None):
    sessao.exigir("financeiro")
    with banco():
        unidades = repo.por_unidade(ano_ini, ano_fim, id_unidade)
        k = repo.kpis(ano_ini, ano_fim, id_unidade)
        procs = repo.por_procedimento(ano_ini, ano_fim, id_unidade)
        lanc = repo.listar_lancamentos(ano_ini, ano_fim, id_unidade)
        gerais = ZERO if id_unidade else repo.despesas_gerais(ano_ini, ano_fim)
    soma = lambda chave: sum((u[chave] or ZERO for u in unidades), ZERO)
    margem = soma("margem")
    return dict(
        faturamento=soma("faturamento"), custo_locacao=soma("custo_locacao"),
        despesas=soma("despesas"), margem=margem, dias=sum(u["dias"] or 0 for u in unidades),
        realizados=int(k["realizados"]), unidades=unidades, procedimentos=procs,
        lancamentos=lanc, despesas_gerais=gerais, resultado_geral=margem - gerais)


CATEGORIAS_SUGERIDAS = ["Marketing", "Contabilidade", "Software", "Limpeza", "Manutenção",
                        "Material de escritório", "Venda de produtos", "Outros"]
CAMPOS_LANCAMENTO = [
    Campo("tipo", "Tipo", "escolha", opcoes=("DESPESA", "RECEITA")),
    Campo("id_unidade", "Unidade", "id", obrigatorio=False),
    Campo("categoria", "Categoria", maximo=40),
    Campo("descricao", "Descrição", maximo=200),
    Campo("valor", "Valor", "decimal", maior_que_zero=True),
    Campo("data_lancamento", "Data", "data"),
]


def salvar_lancamento(sessao, dados, id_=None):
    sessao.exigir("financeiro", editar=True)
    d = validar_ou_falhar(dados, CAMPOS_LANCAMENTO)
    with banco():
        if id_ is None:
            return repo.inserir_lancamento(d)
        repo.atualizar_lancamento(id_, d)
        return id_


# ---------- Dashboard ----------
def dashboard(sessao, ano_ini, ano_fim, id_unidade=None, id_procedimento=None):
    """Todos os visuais com os mesmos filtros. Com filtro de procedimento, o
    faturamento vem de vw_dash_procedimento (a única view com procedimento);
    custos de locação e despesas não dependem de procedimento."""
    sessao.exigir("dashboard")
    with banco():
        unidades = repo.por_unidade(ano_ini, ano_fim, id_unidade)
        k = repo.kpis(ano_ini, ano_fim, id_unidade)
        comp = repo.comparecimento(ano_ini, ano_fim, id_unidade)
        procs = repo.por_procedimento(ano_ini, ano_fim, id_unidade, id_procedimento)
        mensal = repo.mensal(ano_ini, ano_fim, id_unidade)
        ret = repo.retornos(id_unidade, id_procedimento)
        cidades = repo.pacientes_cidade_bairro()
        estoque = repo.estoque_alertas()
        validade = repo.validade_alertas()
        if id_procedimento:
            proc_un = repo.procedimento_por_unidade_mes(ano_ini, ano_fim, id_unidade,
                                                        id_procedimento)
    if id_procedimento:
        fat_un = {}
        fat_mes = {}
        for linha in proc_un:
            fat_un[linha["id_unidade"]] = fat_un.get(linha["id_unidade"], ZERO) + linha["faturamento"]
            fat_mes[linha["ano_mes"]] = fat_mes.get(linha["ano_mes"], ZERO) + linha["faturamento"]
        for u in unidades:
            u["faturamento"] = fat_un.get(u["id_unidade"], ZERO)
        mensal = [dict(ano_mes=m, faturamento=v) for m, v in sorted(fat_mes.items())]
        faturamento = sum(fat_un.values(), ZERO)
        quantidade = sum(int(p["quantidade"]) for p in procs)
    else:
        faturamento = sum((u["faturamento"] or ZERO for u in unidades), ZERO)
        quantidade = int(k["realizados"])
    custo = sum((u["custo_locacao"] + u["despesas"] for u in unidades), ZERO)
    vencidos = [r for r in ret if r["vencido"]]
    retornaram = [r for r in vencidos if r["retornou"]]
    pacientes_ativos = sum(int(c["pacientes_ativos"]) for c in cidades)
    return dict(
        faturamento=faturamento,
        faturamento_por_unidade=[(u["nome_clinica"], u["faturamento"] or ZERO) for u in unidades],
        custo_por_unidade=[(u["nome_clinica"], u["custo_locacao"] + u["despesas"])
                           for u in unidades],
        margem_liquida=faturamento - custo,
        taxa_retorno=_razao(len(retornaram), len(vencidos)),
        taxa_comparecimento=_razao(comp["realizados"], comp["realizados"] + comp["faltas"]),
        ticket_medio=(faturamento / quantidade) if quantidade else None,
        pacientes_ativos=pacientes_ativos,
        por_procedimento=[(p["nome_procedimento"], p["faturamento"]) for p in procs],
        mensal=[(m["ano_mes"], m["faturamento"]) for m in mensal],
        cidades=cidades,
        retornos_pendentes=[r for r in vencidos if not r["retornou"]],
        estoque_alertas=estoque, validade_alertas=validade)
