"""Tela Financeiro (só Gerente)."""
from datetime import date

import customtkinter as ctk

from interface.componentes import (Abas, Barras, BotaoPrincipal, Campo, Cartao, Mensagem,
                                   RodapeFormulario, Seletor, Tabela, caixa_rolagem,
                                   grade_kpis)
from interface.formatos import brl, formatar_data, mes_extenso, numero, percentual
from interface.tema import Cor, Espaco, Fonte, Medida
from interface.telas.base import FALHOU, TelaBase
from servicos import cadastros, relatorios as srv

NOTA = ("Base de cálculo: atendimentos realizados no período (faltas e cancelamentos não "
        "contam). Custo de locação = valor de locação da unidade x dias com atendimento "
        "realizado (SUPOSIÇÃO, a confirmar com a cliente). Margem = faturamento - locação - "
        "despesas lançadas para a unidade.")


class TelaFinanceiro(TelaBase):
    MODULO = "financeiro"
    TITULO, SUBTITULO = "Financeiro", "Faturamento e rentabilidade por unidade"

    def __init__(self, master, app):
        super().__init__(master, app, self.TITULO, self.SUBTITULO)
        meses = self.chamar(srv.meses)
        self.meses = [] if meses is FALHOU else meses
        unidades = self.chamar(cadastros.unidades_ativas)
        self.unidades = [] if unidades is FALHOU else unidades
        hoje = date.today().strftime("%Y-%m")
        passados = [m for m in self.meses if m < hoje] or self.meses
        self.filtro = dict(de=passados[-3] if len(passados) >= 3 else (passados or [hoje])[0],
                           ate=passados[-1] if passados else hoje, unidade=None)
        self.aba = "resumo"
        self.mostrar()

    def mostrar(self, aviso=""):
        self.limpar()
        self.cabecalho.trocar(self.TITULO, self.SUBTITULO)
        self.conteudo.grid_rowconfigure(3, weight=1)
        barra = ctk.CTkFrame(self.conteudo, fg_color="transparent")
        barra.grid(row=0, column=0, sticky="ew")
        op_meses = [(m, mes_extenso(m)) for m in self.meses]
        self.f_de = Seletor(barra, op_meses, vazio="De", width=Medida.FILTRO_LARGURA,
                            comando=lambda _v: self._filtrar())
        self.f_de.grid(row=0, column=0)
        self.f_ate = Seletor(barra, op_meses, vazio="Até", width=Medida.FILTRO_LARGURA,
                             comando=lambda _v: self._filtrar())
        self.f_ate.grid(row=0, column=1, padx=(Espaco.M, 0))
        self.f_un = Seletor(barra, [(u["id_unidade"], u["nome_clinica"]) for u in self.unidades],
                            vazio="Todas as unidades", width=Medida.FILTRO_LARGURA,
                            comando=lambda _v: self._filtrar())
        self.f_un.grid(row=0, column=2, padx=(Espaco.M, 0))
        self.f_de.definir(self.filtro["de"])
        self.f_ate.definir(self.filtro["ate"])
        self.f_un.definir(self.filtro["unidade"])
        barra.grid_columnconfigure(3, weight=1)
        BotaoPrincipal(barra, "Novo lançamento", lambda: self.form_lancamento()).grid(
            row=0, column=4, sticky="e")
        self.abas = Abas(self.conteudo, [("resumo", "Resumo"), ("lancamentos", "Lançamentos")],
                         self._trocar_aba, ativa=self.aba)
        self.abas.grid(row=1, column=0, sticky="ew", pady=(Espaco.L, 0))
        self.mensagem = Mensagem(self.conteudo)
        self.mensagem.grid(row=2, column=0, sticky="ew", pady=Espaco.S)
        self.area = caixa_rolagem(self.conteudo)
        self.area.grid(row=3, column=0, sticky="nsew")
        self.area.grid_columnconfigure(0, weight=1)
        self.carregar()
        if aviso:
            self.sucesso(aviso)

    def _trocar_aba(self, aba):
        self.aba = aba
        self.carregar()

    def _filtrar(self):
        self.filtro.update(de=self.f_de.valor(), ate=self.f_ate.valor(),
                           unidade=self.f_un.valor())
        self.carregar()

    def carregar(self):
        for w in self.area.winfo_children():
            w.destroy()
        self.mensagem.limpar()
        f = self.filtro
        if not f["de"] or not f["ate"]:
            self.erro("Escolha o mês inicial e o mês final do período.")
            return
        if f["de"] > f["ate"]:
            self.erro("O mês inicial deve ser anterior ou igual ao mês final.")
            return
        d = self.chamar(srv.financeiro, f["de"], f["ate"], f["unidade"])
        if d is FALHOU:
            return
        if self.aba == "lancamentos":
            self._lancamentos(d)
        else:
            self._resumo(d)

    def _resumo(self, d):
        fat = d["faturamento"]
        margem_pct = percentual(d["margem"] / fat, 0) + " do faturamento" if fat else "Sem faturamento no período"
        kpis = [
            ("Faturamento", brl(fat), f"{d['realizados']} atendimentos realizados"),
            ("Custo de locação", brl(d["custo_locacao"]), f"{d['dias']} dias com atendimento"),
            ("Despesas das unidades", brl(d["despesas"]), "Lançamentos com unidade"),
            ("Margem", brl(d["margem"]), margem_pct),
        ]
        if not self.filtro["unidade"]:
            kpis += [("Despesas gerais", brl(d["despesas_gerais"]), "Lançamentos sem unidade"),
                     ("Resultado após despesas gerais", brl(d["resultado_geral"]),
                      "Margem - despesas gerais")]
        grade_kpis(self.area, kpis, 3).grid(row=0, column=0, sticky="ew")
        self._titulo(1, "Resultado por unidade")
        t = Tabela(self.area, [("Unidade", 3, "w"), ("Faturamento", 2, "e"),
                               ("Dias", 1, "e"), ("Locação", 2, "e"), ("Despesas", 2, "e"),
                               ("Margem", 2, "e")], "Sem dados no período.", rolagem=False)
        t.grid(row=2, column=0, sticky="ew")
        t.preencher([[u["nome_clinica"].replace("Unidade ", ""), brl(u["faturamento"]),
                      str(u["dias"]), brl(u["custo_locacao"]), brl(u["despesas"]),
                      (brl(u["margem"]), Cor.ERRO if u["margem"] < 0 else Cor.TEXTO)]
                     for u in d["unidades"]])
        self._titulo(3, "Faturamento x custo por unidade")
        Barras(self.area, [(u["nome_clinica"].replace("Unidade ", ""), [
            ("Faturamento", u["faturamento"], Cor.OURO, brl(u["faturamento"])),
            ("Locação + despesas", u["custo_locacao"] + u["despesas"], Cor.TAUPE,
             brl(u["custo_locacao"] + u["despesas"]))]) for u in d["unidades"]]
               ).grid(row=4, column=0, sticky="ew")
        self._titulo(5, "Faturamento por procedimento")
        t2 = Tabela(self.area, [("Procedimento", 4, "w"), ("Aplicações", 1, "e"),
                                ("Faturamento", 2, "e")],
                    "Sem procedimentos realizados no período.", rolagem=False)
        t2.grid(row=6, column=0, sticky="ew")
        t2.preencher([[p["nome_procedimento"], numero(p["quantidade"]), brl(p["faturamento"])]
                      for p in d["procedimentos"]])
        ctk.CTkLabel(self.area, text=NOTA, font=Fonte.pequeno, text_color=Cor.TEXTO_SECUNDARIO,
                     anchor="w", justify="left", wraplength=Medida.BUSCA_LARGURA * 2
                     ).grid(row=7, column=0, sticky="ew", pady=(Espaco.L, 0))

    def _titulo(self, linha, texto):
        ctk.CTkLabel(self.area, text=texto, font=Fonte.h2, text_color=Cor.TEXTO,
                     anchor="w").grid(row=linha, column=0, sticky="ew",
                                      pady=(Espaco.XL, Espaco.M))

    def _lancamentos(self, d):
        t = Tabela(self.area, [("Data", 1, "w"), ("Tipo", 1, "w"), ("Unidade", 2, "w"),
                               ("Categoria", 2, "w"), ("Descrição", 4, "w"), ("Valor", 2, "e")],
                   "Nenhum lançamento no período.", rolagem=False,
                   acoes=lambda l: [("Editar", lambda: self.form_lancamento(l))])
        t.grid(row=0, column=0, sticky="ew")
        t.preencher([[formatar_data(l["data_lancamento"]),
                      ("Despesa", Cor.TEXTO) if l["tipo"] == "DESPESA" else ("Receita", Cor.SUCESSO),
                      (l["nome_clinica"] or "Geral").replace("Unidade ", ""), l["categoria"],
                      l["descricao"], brl(l["valor"])] for l in d["lancamentos"]],
                    d["lancamentos"])

    # formulário de lançamento
    def form_lancamento(self, l=None):
        self.limpar()
        self.cabecalho.trocar("Editar lançamento" if l else "Novo lançamento", "")
        self.colocar_rodape(RodapeFormulario(self, lambda: self.mostrar(),
                                             lambda: self._salvar_lancamento(l)))
        cartao = Cartao(self.conteudo)
        cartao.grid(row=0, column=0, sticky="new")
        grade = ctk.CTkFrame(cartao, fg_color="transparent")
        grade.pack(fill="x", padx=Espaco.XL, pady=(Espaco.S, Espaco.XL))
        grade.grid_columnconfigure((0, 1), weight=1, uniform="campo")
        especs = [
            ("tipo", "Tipo", dict(opcoes=[("DESPESA", "Despesa"), ("RECEITA", "Receita")])),
            ("id_unidade", "Unidade", dict(opcoes=[(u["id_unidade"], u["nome_clinica"])
                                                   for u in self.unidades],
                                           vazio="Geral (sem unidade)")),
            ("categoria", "Categoria", dict(sugestoes=srv.CATEGORIAS_SUGERIDAS)),
            ("data_lancamento", "Data", dict(dica="dd/mm/aaaa")),
            ("valor", "Valor (R$)", dict(dica="Ex.: 150,00")),
            ("descricao", "Descrição", dict()),
        ]
        self.campos = {}
        for i, (chave, rotulo, kw) in enumerate(especs):
            campo = Campo(grade, rotulo, **kw)
            linha, coluna = divmod(i, 2)
            campo.grid(row=linha, column=coluna, sticky="new", pady=(Espaco.L, 0),
                       padx=(0, Espaco.M) if coluna == 0 else (Espaco.M, 0))
            self.campos[chave] = campo
        if l:
            for chave, valor in dict(tipo=l["tipo"], id_unidade=l["id_unidade"],
                                     categoria=l["categoria"], descricao=l["descricao"],
                                     data_lancamento=formatar_data(l["data_lancamento"]),
                                     valor=numero(l["valor"]).replace(".", "")).items():
                self.campos[chave].definir(valor)
        else:
            self.campos["tipo"].definir("DESPESA")
            self.campos["data_lancamento"].definir(formatar_data(date.today()))

    def _salvar_lancamento(self, l):
        dados = {k: c.valor() for k, c in self.campos.items()}

        def invalido(erro):
            for k, c in self.campos.items():
                c.mostrar_erro(erro.erros.get(k, ""))
            self.erro("Corrija os campos destacados.")

        r = self.chamar(srv.salvar_lancamento, dados, l["id_lancamento"] if l else None,
                        ao_invalido=invalido)
        if r is FALHOU:
            return
        self.aba = "lancamentos"
        self.mostrar(aviso="Lançamento salvo.")
