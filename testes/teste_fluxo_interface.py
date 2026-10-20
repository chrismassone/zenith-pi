"""Fluxo pela interface: atendimentos, procedimentos, unidades, insumos, financeiro e dashboard."""
from datetime import date, timedelta
from decimal import Decimal

from testes.fluxo_util import PREFIXO, Fluxo
from interface.telas.atendimentos import DialogoConsumo
from repositorios.base import consultar

f = Fluxo("modulos")
ontem = (date.today() - timedelta(days=1 if date.today().weekday() else 3)).strftime("%d/%m/%Y")
criados = dict(atendimentos=[], compras=[], consumos=[])


def saldo(nome):
    return consultar("SELECT saldo FROM vw_estoque_atual WHERE nome_insumo=%s", (nome,),
                     um=True)["saldo"]


def ultimo_id(tabela, chave):
    return consultar(f"SELECT MAX({chave}) m FROM {tabela}", um=True)["m"] or 0


def registrar_novo(lista, tabela, chave, antes):
    """Guarda para limpeza só o id que o teste criou."""
    depois = ultimo_id(tabela, chave)
    if depois > antes:
        lista.append(depois)
        return depois
    return None


def responder_consumo(ajustes, foto=None):
    def agir():
        d = f.dialogo(DialogoConsumo)
        if d is None or not d.winfo_viewable():
            f.depois(100, agir)
            return
        for s, e in zip(d.sugestao, d.entradas):
            if s["nome_insumo"] in ajustes:
                e.delete(0, "end")
                e.insert(0, ajustes[s["nome_insumo"]])
        if foto:
            f.foto(foto)
        d.confirmar()
    f.depois(400, agir)


try:
    f.entrar("Gerente")

    # atendimentos
    f.j.mostrar("atendimentos")
    t = f.tela()
    f.foto("01_atendimentos_lista")
    t.f_status.definir("Realizado")
    t.f_unidade.definir(2)
    t.carregar()
    f.passo()
    f.ok("Filtro por unidade e situação", all("Tatuapé" in l[3] and l[4][0] == "Realizado"
                                              for l in t.tabela._linhas))
    f.foto("02_atendimentos_filtro")
    t.f_status.definir(None)
    t.f_unidade.definir(None)
    t.mostrar_formulario()
    f.passo()
    t.campos["id_paciente"].definir(1)
    t.campos["id_unidade"].definir(1)
    t.campos["data"].definir(ontem)
    t.campos["hora"].definir("08:15")
    linha = t.linhas[0]
    linha["proc"].definir(1)
    linha["proc"]._escolheu(None)
    f.ok("Preço de tabela preenchido ao escolher o procedimento",
         linha["valor"].get() == "1200")
    linha["regiao"].insert(0, "Glabela (fictício)")
    linha["qtd"].insert(0, "30")
    t._atualizar_total()
    f.ok("Total calculado", "Valor total R$ 1.200,00" in t.rotulo_total.cget("text"))
    f.foto("03_atendimento_novo")
    antes_at = ultimo_id("atendimento", "id_atendimento")
    t._salvar()
    f.passo()
    id_at = registrar_novo(criados["atendimentos"], "atendimento", "id_atendimento", antes_at)
    f.ok("Agendado salvo", consultar("SELECT status FROM atendimento WHERE id_atendimento=%s",
                                     (id_at,), um=True)["status"] == "Agendado")

    # marcar Realizado: insumos sugeridos com quantidade editável
    t = f.tela()
    t.mostrar_formulario(id_at)
    f.passo()
    t.campos["status"].definir("Realizado")
    t.campos["forma_pagamento"].definir("Pix")
    t.campos["desconto"].definir("100")
    botox_antes = saldo("Botox")
    responder_consumo({"Botox": "33"}, foto="04_dialogo_insumos")
    t._salvar()
    f.passo()
    consumo = consultar("SELECT c.quantidade FROM consumo c JOIN insumo i USING (id_insumo) "
                        "WHERE c.id_atendimento=%s AND i.nome_insumo='Botox'", (id_at,), um=True)
    f.ok("Consumo registrado com a quantidade ajustada (33 U)",
         consumo and consumo["quantidade"] == Decimal("33.00"))
    f.ok("Saldo do Botox baixou 33", botox_antes - saldo("Botox") == Decimal("33.00"))
    f.ok("Total com desconto pela view", consultar(
        "SELECT valor_total v FROM vw_valor_atendimento WHERE id_atendimento=%s", (id_at,),
        um=True)["v"] == Decimal("1100.00"))
    f.foto("05_atendimentos_salvo")

    # saldo insuficiente bloqueado com mensagem clara
    t = f.tela()
    t.mostrar_formulario()
    f.passo()
    for k, v in dict(id_paciente=2, id_unidade=1, data=ontem, hora="08:45", status="Realizado",
                     forma_pagamento="Pix").items():
        t.campos[k].definir(v)
    t.linhas[0]["proc"].definir(7)
    t.linhas[0]["proc"]._escolheu(None)
    t.linhas[0]["regiao"].insert(0, "Olheiras")
    t.linhas[0]["qtd"].insert(0, "1")
    n_antes = consultar("SELECT COUNT(*) n FROM atendimento", um=True)["n"]
    responder_consumo({"Milimetric": str(saldo("Milimetric") + 5)})
    t._salvar()
    f.passo()
    f.ok("Saldo insuficiente: mensagem clara e nada gravado",
         "Saldo insuficiente" in t.mensagem.cget("text")
         and consultar("SELECT COUNT(*) n FROM atendimento", um=True)["n"] == n_antes)
    f.foto("06_saldo_insuficiente")
    t.mostrar_lista()

    # procedimentos
    f.j.mostrar("procedimentos")
    t = f.tela()
    f.foto("07_procedimentos_lista")
    t.mostrar_formulario()
    f.passo()
    t.campos["nome_procedimento"].definir(f"{PREFIXO} Procedimento")
    t.campos["preco_tabela"].definir("350,00")
    t.campos["intervalo_retorno_dias"].definir("90")
    t._nova_linha()
    s, q = t._linhas_insumo[0][1], t._linhas_insumo[0][2]
    s.definir(consultar("SELECT id_insumo FROM insumo WHERE nome_insumo='Gaze estéril'",
                        um=True)["id_insumo"])
    q.insert(0, "2")
    f.foto("08_procedimento_novo")
    t._salvar()
    f.passo()
    proc = consultar("SELECT * FROM procedimento WHERE nome_procedimento LIKE %s",
                     (PREFIXO + "%",), um=True)
    f.ok("Procedimento salvo com o insumo padrão", proc and consultar(
        "SELECT COUNT(*) n FROM procedimento_insumo WHERE id_procedimento=%s",
        (proc["id_procedimento"],), um=True)["n"] == 1)
    t = f.tela()
    t.mostrar_formulario(next(p for p in t.tabela._dados
                              if p["id_procedimento"] == proc["id_procedimento"]))
    f.passo()
    t._remover_linha(t._linhas_insumo[0])
    t._salvar()
    f.passo()
    f.ok("Insumo removido da lista padrão", consultar(
        "SELECT COUNT(*) n FROM procedimento_insumo WHERE id_procedimento=%s",
        (proc["id_procedimento"],), um=True)["n"] == 0)
    t = f.tela()
    t.mostrar_formulario(next(p for p in t.tabela._dados if p["id_procedimento"] == 1))
    f.foto("09_procedimento_editar")

    # unidades
    f.j.mostrar("unidades")
    t = f.tela()
    f.foto("10_unidades")
    t.mostrar_formulario(t.tabela._dados[0])
    t.campos["uf_unidade"].definir("S")
    t._salvar()
    f.passo()
    f.ok("UF inválida recusada", t.campos["uf_unidade"].erro.cget("text")
         == "Informe a UF com duas letras.")
    t.mostrar_lista()

    # insumos
    f.j.mostrar("insumos")
    t = f.tela()
    t.var_alertas.set(True)
    t.carregar_estoque()
    f.passo()
    f.ok("Filtro de alertas mostra só itens em alerta",
         t.tabela._linhas and all(l[5][0] != "OK" for l in t.tabela._linhas))
    f.foto("11_insumos_estoque_alertas")
    t.trocar_aba("movimentos")
    t.form_compra()
    f.passo()
    mili = consultar("SELECT id_insumo FROM insumo WHERE nome_insumo='Milimetric'", um=True)[
        "id_insumo"]
    mili_antes = saldo("Milimetric")
    for k, v in dict(id_insumo=mili, id_fornecedor=1, quantidade="5", preco_unitario="590,00",
                     lote="TESTE01", data_validade="31/12/2027").items():
        t.campos[k].definir(v)
    f.foto("12_compra_form")
    antes_compra = ultimo_id("compra", "id_compra")
    t._salvar_compra()
    f.passo()
    registrar_novo(criados["compras"], "compra", "id_compra", antes_compra)
    f.ok("Compra aumenta o saldo", saldo("Milimetric") - mili_antes == Decimal("5.00"))
    t.form_consumo()
    f.passo()
    t.campos["id_insumo"].definir(mili)
    t.campos["quantidade"].definir("1")
    t._salvar_consumo()
    f.passo()
    f.ok("Consumo avulso sem motivo recusado", t.campos["observacao"].erro.cget("text")
         == "O campo Motivo é obrigatório.")
    t.campos["observacao"].definir("Perda no preparo (teste)")
    antes_consumo = ultimo_id("consumo", "id_consumo")
    t._salvar_consumo()
    f.passo()
    registrar_novo(criados["consumos"], "consumo", "id_consumo", antes_consumo)
    f.ok("Consumo avulso registrado", saldo("Milimetric") - mili_antes == Decimal("4.00"))
    t.seletor_ver.definir("consumos")
    t.carregar_movimentos()
    f.foto("13_insumos_consumos")
    for aba in ("cadastro", "fornecedores"):
        t.trocar_aba(aba)
        f.foto(f"14_insumos_{aba}")

    # financeiro
    f.j.mostrar("financeiro")
    t = f.tela()
    f.foto("15_financeiro_resumo")
    t.form_lancamento()
    f.passo()
    for k, v in dict(id_unidade=1, categoria="Limpeza", valor="80,00",
                     descricao=f"{PREFIXO} lançamento").items():
        t.campos[k].definir(v)
    t._salvar_lancamento(None)
    f.passo()
    f.ok("Lançamento salvo", consultar("SELECT COUNT(*) n FROM lancamento WHERE descricao LIKE %s",
                                       (PREFIXO + "%",), um=True)["n"] == 1)
    f.foto("16_financeiro_lancamentos")

    # dashboard
    f.j.mostrar("dashboard")
    t = f.tela()
    f.foto("17_dashboard")
    t.area._parent_canvas.yview_moveto(0.55)
    f.foto("18_dashboard_graficos")
    t.f_un.definir(3)
    t.f_proc.definir(1)
    t._filtrar()
    f.ok("Dashboard filtrado por unidade e procedimento",
         [n for n, v in t.dados["faturamento_por_unidade"] if v] in ([], ["Unidade Mogi das Cruzes"]))
    f.foto("19_dashboard_filtrado")

    # atendente: unidades só leitura
    f.j.sair()
    f.passo()
    f.entrar("Atendente")
    f.j.mostrar("unidades")
    t = f.tela()
    f.ok("Atendente vê Unidades sem botão de nova unidade nem Inativar",
         not t.pode_editar and all(a[0] == "Ver" for a in [t._acoes(t.tabela._dados[0])[0]]))
    f.foto("20_unidades_atendente")
finally:
    sqls = []
    for i in criados["atendimentos"]:
        sqls += [("DELETE FROM consumo WHERE id_atendimento=%s", (i,)),
                 ("DELETE FROM atendimento_procedimento WHERE id_atendimento=%s", (i,)),
                 ("DELETE FROM atendimento WHERE id_atendimento=%s", (i,))]
    sqls += [("DELETE FROM consumo WHERE id_consumo=%s", (i,)) for i in criados["consumos"] if i]
    sqls += [("DELETE FROM compra WHERE id_compra=%s", (i,)) for i in criados["compras"] if i]
    sqls += [("DELETE FROM procedimento_insumo WHERE id_procedimento IN (SELECT id_procedimento "
              "FROM procedimento WHERE nome_procedimento LIKE %s)", (PREFIXO + "%",)),
             ("DELETE FROM procedimento WHERE nome_procedimento LIKE %s", (PREFIXO + "%",)),
             ("DELETE FROM lancamento WHERE descricao LIKE %s", (PREFIXO + "%",))]
    f.limpar(sqls)
    f.j.destroy()
    print("Registros de teste removidos.")
raise SystemExit(f.relatorio())
