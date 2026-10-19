"""Testes dos serviços de atendimento e estoque, no banco zenith_teste.
Cobre: consumo com quantidade ajustada, saldo negativo bloqueado (no
serviço e no banco), regras do atendimento e permissões. Apaga ao final
tudo o que criou."""
import banco_teste
banco_teste.usar()  # grava só no banco zenith_teste

from datetime import datetime, timedelta
from decimal import Decimal

from repositorios.base import consultar, transacao
from servicos import atendimentos as at, cadastros, estoque, pacientes, relatorios
from servicos.erros import AcessoNegado, DadosInvalidos, SaldoInsuficiente
from servicos.sessao import Sessao

GERENTE = Sessao(dict(id_usuario=0, nome="Teste", email="t@exemplo.invalid",
                      perfil="Gerente", id_profissional=1))
PROFISSIONAL = Sessao(dict(id_usuario=0, nome="Teste", email="p@exemplo.invalid",
                           perfil="Profissional", id_profissional=1))
casos = []
criados = dict(paciente=[], atendimento=[], consumo_avulso=[])


def caso(nome, obtido, esperado):
    casos.append((nome, obtido, esperado))


def erro_de(func):
    try:
        func()
        return None
    except (DadosInvalidos, SaldoInsuficiente, AcessoNegado) as e:
        return e


def saldo(id_insumo):
    return consultar("SELECT saldo FROM vw_estoque_atual WHERE id_insumo = %s",
                     (id_insumo,), um=True)["saldo"]


def id_insumo(nome):
    return consultar("SELECT id_insumo FROM insumo WHERE nome_insumo = %s", (nome,), um=True)[
        "id_insumo"]


# ---------------- lógica pura ----------------
sug = at.agregar_sugestoes(
    [dict(id_procedimento=1, id_insumo=10, quantidade_padrao=Decimal("2"), nome_insumo="A",
          marca="", unidade_medida="un", saldo=Decimal("9")),
     dict(id_procedimento=2, id_insumo=10, quantidade_padrao=Decimal("1"), nome_insumo="A",
          marca="", unidade_medida="un", saldo=Decimal("9"))], [1, 1, 2])
caso("Sugestão soma por insumo e por vez do procedimento", sug[0]["quantidade_sugerida"],
     Decimal("5"))
caso("Consumo zero é descartado", at.validar_consumos(
    [dict(id_insumo=1, quantidade="0"), dict(id_insumo=2, quantidade="1,5")]),
    [(2, Decimal("1.50"))])
caso("Quantidade inválida recusada",
     "consumo" in erro_de(lambda: at.validar_consumos([dict(id_insumo=1, quantidade="x")])).erros,
     True)
e = erro_de(lambda: at.conferir_saldo([(7, Decimal("5"))], {7: dict(
    saldo=Decimal("2"), nome_insumo="Milimetric", unidade_medida="mL")}))
caso("Saldo insuficiente: mensagem clara",
     isinstance(e, SaldoInsuficiente) and "Milimetric: disponível 2 mL, informado 5 mL" in e.mensagem,
     True)
itens = [dict(valor_cobrado=Decimal("100.00")), dict(valor_cobrado=Decimal("50.00"))]
caso("Total = itens - desconto", at.total(itens, Decimal("30")), Decimal("120.00"))
caso("Total nunca negativo", at.total(itens, Decimal("500")), Decimal("0.00"))

# ---------------- serviços com banco ----------------
try:
    id_pac = pacientes.salvar(GERENTE, dict(
        nome_completo="Paciente Ficticio Servico", cpf="111.444.777-35", data_nasc="10/05/1990",
        telefone_paciente="(11) 98765-4321", email_paciente="servico@exemplo.invalid",
        cep_paciente="03047-000", endereco_paciente="Rua Ficticia, 1", bairro_paciente="Mooca",
        cidade_paciente="São Paulo", origem_captacao="Indicação"))
    criados["paciente"].append(id_pac)
    ontem = (datetime.now() - timedelta(days=1)).strftime("%d/%m/%Y")
    cab = dict(id_paciente=id_pac, id_profissional=1, id_unidade=1, data=ontem, hora="10:00",
               status="Agendado", forma_pagamento=None, desconto="", observacao="")
    linhas = [dict(id_procedimento=1, regiao_aplicada="Testa", quantidade_aplicada="30",
                   valor_cobrado="1200")]
    id_at = at.salvar(GERENTE, cab, linhas)
    criados["atendimento"].append(id_at)
    caso("Agendado não registra consumo",
         consultar("SELECT COUNT(*) n FROM consumo WHERE id_atendimento=%s", (id_at,), um=True)["n"], 0)

    caso("Realizado sem forma de pagamento é recusado",
         "forma_pagamento" in erro_de(lambda: at.salvar(GERENTE, {**cab, "status": "Realizado"},
                                                        linhas, [], id_at)).erros, True)
    caso("Desconto maior que o valor é recusado",
         "desconto" in erro_de(lambda: at.salvar(GERENTE, {**cab, "desconto": "5000"},
                                                 linhas, None, id_at)).erros, True)
    amanha = (datetime.now() + timedelta(days=1)).strftime("%d/%m/%Y")
    caso("Faltou no futuro é recusado",
         "data" in erro_de(lambda: at.salvar(GERENTE, {**cab, "status": "Faltou", "data": amanha},
                                             linhas, None, id_at)).erros, True)
    caso("Realizado exige confirmar os insumos",
         None in erro_de(lambda: at.salvar(GERENTE, {**cab, "status": "Realizado",
                                                     "forma_pagamento": "Pix"},
                                           linhas, None, id_at)).erros, True)

    # quantidade ajustada pela profissional
    sugestao = at.sugerir_consumo(GERENTE, linhas)
    botox = id_insumo("Botox")
    padrao_botox = next(s for s in sugestao if s["id_insumo"] == botox)["quantidade_sugerida"]
    antes = saldo(botox)
    consumos = [dict(id_insumo=s["id_insumo"], nome_insumo=s["nome_insumo"],
                     quantidade="32" if s["id_insumo"] == botox else str(s["quantidade_sugerida"]))
                for s in sugestao]
    real = {**cab, "status": "Realizado", "forma_pagamento": "Pix"}
    at.salvar(GERENTE, real, linhas, consumos, id_at)
    gravado = consultar("SELECT quantidade FROM consumo WHERE id_atendimento=%s AND id_insumo=%s",
                        (id_at, botox), um=True)["quantidade"]
    caso("Sugestão usa a quantidade padrão (50 U)", padrao_botox, Decimal("50.00"))
    caso("Consumo grava a quantidade REAL ajustada (32 U)", gravado, Decimal("32.00"))
    caso("Saldo cai exatamente o consumido", antes - saldo(botox), Decimal("32.00"))
    caso("Valor do atendimento pela view",
         consultar("SELECT valor_total FROM vw_valor_atendimento WHERE id_atendimento=%s",
                   (id_at,), um=True)["valor_total"], Decimal("1200.00"))
    caso("Realizado não pode voltar a Agendado",
         "status" in erro_de(lambda: at.salvar(GERENTE, cab, linhas, None, id_at)).erros, True)
    at.salvar(GERENTE, {**real, "observacao": "editado"}, linhas, None, id_at)
    caso("Editar realizado não duplica consumo",
         consultar("SELECT COUNT(*) n FROM consumo WHERE id_atendimento=%s AND id_insumo=%s",
                   (id_at, botox), um=True)["n"], 1)

    # alterar a quantidade padrão não reescreve o passado
    lista = [dict(id_insumo=i["id_insumo"], quantidade_padrao=str(i["quantidade_padrao"]))
             for i in cadastros.insumos_do_procedimento(GERENTE, 1)]
    proc = next(p for p in cadastros.listar_procedimentos(GERENTE) if p["id_procedimento"] == 1)
    dados_proc = dict(nome_procedimento=proc["nome_procedimento"],
                      preco_tabela=str(proc["preco_tabela"]),
                      intervalo_retorno_dias=str(proc["intervalo_retorno_dias"]))
    novo = [dict(l, quantidade_padrao="45") if l["id_insumo"] == botox else l for l in lista]
    cadastros.salvar_procedimento(GERENTE, dados_proc, novo, 1)
    caso("Padrão alterado para 45 U",
         consultar("SELECT quantidade_padrao q FROM procedimento_insumo WHERE id_procedimento=1 "
                   "AND id_insumo=%s", (botox,), um=True)["q"], Decimal("45.00"))
    caso("Consumo passado continua 32 U",
         consultar("SELECT quantidade FROM consumo WHERE id_atendimento=%s AND id_insumo=%s",
                   (id_at, botox), um=True)["quantidade"], Decimal("32.00"))
    cadastros.salvar_procedimento(GERENTE, dados_proc, lista, 1)   # volta ao original

    # saldo negativo bloqueado
    mili = id_insumo("Milimetric")
    linhas_ol = [dict(id_procedimento=7, regiao_aplicada="Olheiras", quantidade_aplicada="1",
                      valor_cobrado="1600")]
    sug_ol = at.sugerir_consumo(GERENTE, linhas_ol)
    excesso = [dict(id_insumo=s["id_insumo"], nome_insumo=s["nome_insumo"],
                    quantidade=str(saldo(mili) + 1) if s["id_insumo"] == mili else "0")
               for s in sug_ol]
    n_antes = consultar("SELECT COUNT(*) n FROM atendimento", um=True)["n"]
    e = erro_de(lambda: at.salvar(GERENTE, {**real}, linhas_ol, excesso))
    caso("Consumo acima do saldo bloqueado no serviço", isinstance(e, SaldoInsuficiente), True)
    caso("Nada gravado quando o saldo falta",
         consultar("SELECT COUNT(*) n FROM atendimento", um=True)["n"], n_antes)
    try:
        with transacao() as cur:
            cur.execute("INSERT INTO consumo (id_insumo, quantidade, observacao) VALUES (%s,%s,%s)",
                        (mili, saldo(mili) + 1, "teste"))
        bloqueou = False
    except Exception:  # noqa: BLE001
        bloqueou = True
    caso("Banco também bloqueia (gatilho)", bloqueou, True)

    # consumo avulso
    caso("Consumo avulso sem motivo recusado",
         "observacao" in erro_de(lambda: estoque.registrar_consumo_avulso(
             GERENTE, dict(id_insumo=mili, quantidade="1", observacao=""))).erros, True)
    caso("Consumo avulso acima do saldo recusado",
         isinstance(erro_de(lambda: estoque.registrar_consumo_avulso(
             GERENTE, dict(id_insumo=mili, quantidade=str(saldo(mili) + 1),
                           observacao="Perda"))), SaldoInsuficiente), True)
    gaze = id_insumo("Gaze estéril")
    s0 = saldo(gaze)
    criados["consumo_avulso"].append(estoque.registrar_consumo_avulso(
        GERENTE, dict(id_insumo=gaze, quantidade="2", observacao="Teste automatizado")))
    caso("Consumo avulso válido baixa o saldo", s0 - saldo(gaze), Decimal("2.00"))

    # permissões
    caso("Profissional não acessa o Financeiro",
         isinstance(erro_de(lambda: relatorios.financeiro(PROFISSIONAL, "2026-01", "2026-02")),
                    AcessoNegado), True)
    caso("Profissional não registra compra",
         isinstance(erro_de(lambda: estoque.registrar_compra(PROFISSIONAL, {})), AcessoNegado), True)
finally:
    with transacao() as cur:
        for i in criados["consumo_avulso"]:
            cur.execute("DELETE FROM consumo WHERE id_consumo=%s", (i,))
        for i in criados["atendimento"]:
            cur.execute("DELETE FROM consumo WHERE id_atendimento=%s", (i,))
            cur.execute("DELETE FROM atendimento_procedimento WHERE id_atendimento=%s", (i,))
            cur.execute("DELETE FROM atendimento WHERE id_atendimento=%s", (i,))
        for i in criados["paciente"]:
            cur.execute("DELETE FROM paciente WHERE id_paciente=%s", (i,))
    print("Registros de teste removidos.")

falhas = 0
for nome, obtido, esperado in casos:
    ok = obtido == esperado
    falhas += not ok
    print(("OK   " if ok else "FALHA"), nome, "" if ok else f"(obtido {obtido!r})")
print(f"\n{len(casos) - falhas}/{len(casos)} testes passaram")
