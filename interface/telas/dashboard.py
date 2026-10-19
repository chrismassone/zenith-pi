"""Tela Dashboard (somente Gerente): espelho do Power BI. Lê só as views
vw_* (via servicos.relatorios.dashboard), com os filtros Unidade, Período
e Procedimento aplicados a todos os visuais."""
from datetime import date

import customtkinter as ctk
import matplotlib
matplotlib.use("Agg")   # o desenho vai para o Tk pelo FigureCanvasTkAgg
from matplotlib import font_manager                              # noqa: E402
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg   # noqa: E402
from matplotlib.figure import Figure                             # noqa: E402

from interface import tema                                       # noqa: E402
from interface.componentes import (Cartao, Mensagem, Seletor, Tabela, caixa_rolagem,  # noqa: E402
                                   grade_kpis)
from interface.formatos import (brl, formatar_data, formatar_telefone, mes_curto, mes_extenso, numero,  # noqa: E402
                                percentual)
from interface.tema import Cor, Espaco, Fonte, Medida             # noqa: E402
from interface.telas.base import FALHOU, TelaBase                 # noqa: E402
from servicos import cadastros, relatorios as srv                 # noqa: E402


def _configurar_fonte():
    for arq in tema.ARQUIVOS_FONTES:
        caminho = tema.PASTA_FONTES / arq
        if caminho.exists():
            font_manager.fontManager.addfont(str(caminho))
    nomes = {f.name for f in font_manager.fontManager.ttflist}
    familia = "Montserrat" if "Montserrat" in nomes else "Segoe UI"
    matplotlib.rcParams.update({
        "font.family": familia, "font.size": Medida.GRAFICO_FONTE, "text.color": Cor.TEXTO,
        "axes.labelcolor": Cor.TEXTO, "xtick.color": Cor.TEXTO_SECUNDARIO,
        "ytick.color": Cor.TEXTO_SECUNDARIO, "axes.edgecolor": Cor.BORDA_SUAVE,
        "axes.facecolor": Cor.FUNDO, "figure.facecolor": Cor.FUNDO,
        "axes.spines.top": False, "axes.spines.right": False,
        "axes.titleweight": "bold", "axes.titlesize": Medida.GRAFICO_FONTE_TITULO, "axes.titlecolor": Cor.TEXTO,
        "axes.titlelocation": "left"})


def _milhar(v, _pos=None):
    return f"{v / 1000:.0f} mil" if abs(v) >= 1000 else f"{v:.0f}"


class TelaDashboard(TelaBase):
    MODULO = "dashboard"
    TITULO = "Dashboard"
    SUBTITULO = "Indicadores do consultório (mesmos números do Power BI)"

    def __init__(self, master, app):
        super().__init__(master, app, self.TITULO, self.SUBTITULO)
        _configurar_fonte()
        meses = self.chamar(srv.meses)
        self.meses = [] if meses is FALHOU else meses
        unidades = self.chamar(cadastros.unidades_ativas)
        procs = self.chamar(cadastros.procedimentos_ativos)
        self.unidades = [] if unidades is FALHOU else unidades
        self.procs = [] if procs is FALHOU else procs
        hoje = date.today().strftime("%Y-%m")
        self.filtro = dict(de=self.meses[0] if self.meses else hoje,
                           ate=self.meses[-1] if self.meses else hoje,
                           unidade=None, procedimento=None)
        self._figuras = []
        self.montar()

    def montar(self):
        self.conteudo.grid_rowconfigure(2, weight=1)
        barra = ctk.CTkFrame(self.conteudo, fg_color="transparent")
        barra.grid(row=0, column=0, sticky="ew")
        op = [(m, mes_extenso(m)) for m in self.meses]
        self.f_de = Seletor(barra, op, vazio="De", width=Medida.FILTRO_LARGURA,
                            comando=lambda _v: self._filtrar())
        self.f_ate = Seletor(barra, op, vazio="Até", width=Medida.FILTRO_LARGURA,
                             comando=lambda _v: self._filtrar())
        self.f_un = Seletor(barra, [(u["id_unidade"], u["nome_clinica"]) for u in self.unidades],
                            vazio="Todas as unidades", width=Medida.FILTRO_LARGURA,
                            comando=lambda _v: self._filtrar())
        self.f_proc = Seletor(barra, [(p["id_procedimento"], p["nome_procedimento"])
                                      for p in self.procs],
                              vazio="Todos os procedimentos", width=Medida.FILTRO_LARGURA,
                              comando=lambda _v: self._filtrar())
        for i, s in enumerate((self.f_de, self.f_ate, self.f_un, self.f_proc)):
            s.grid(row=0, column=i, padx=(0 if i == 0 else Espaco.M, 0))
        self.f_de.definir(self.filtro["de"])
        self.f_ate.definir(self.filtro["ate"])
        self.mensagem = Mensagem(self.conteudo)
        self.mensagem.grid(row=1, column=0, sticky="ew", pady=Espaco.S)
        self.area = caixa_rolagem(self.conteudo)
        self.area.grid(row=2, column=0, sticky="nsew")
        self.area.grid_columnconfigure((0, 1), weight=1, uniform="graf")
        self.carregar()

    def _filtrar(self):
        self.filtro.update(de=self.f_de.valor(), ate=self.f_ate.valor(),
                           unidade=self.f_un.valor(), procedimento=self.f_proc.valor())
        self.carregar()

    def _limpar_area(self):
        for fig in self._figuras:
            fig.clear()
        self._figuras = []
        for w in self.area.winfo_children():
            w.destroy()

    def carregar(self):
        self._limpar_area()
        self.mensagem.limpar()
        f = self.filtro
        if not f["de"] or not f["ate"] or f["de"] > f["ate"]:
            self.erro("Escolha um período válido: o mês inicial deve vir antes do final.")
            return
        d = self.chamar(srv.dashboard, f["de"], f["ate"], f["unidade"], f["procedimento"])
        if d is FALHOU:
            return
        self.dados = d   # usado pelo teste que compara com o SQL
        por_un = " · ".join(f"{n.replace('Unidade ', '')} {brl(v)}"
                            for n, v in d["faturamento_por_unidade"])
        kpis = [
            ("Faturamento total", brl(d["faturamento"]), "Só atendimentos realizados"),
            ("Margem líquida", brl(d["margem_liquida"]),
             "Faturamento - locação - despesas das unidades"),
            ("Ticket médio", brl(d["ticket_medio"]), "Faturamento por atendimento realizado"
             if not f["procedimento"] else "Faturamento por aplicação do procedimento"),
            ("Taxa de comparecimento", percentual(d["taxa_comparecimento"]),
             "Realizados / (realizados + faltas)"),
            ("Taxa de retorno", percentual(d["taxa_retorno"]),
             "Retornaram após o prazo de retorno vencer"),
            ("Pacientes ativos", str(d["pacientes_ativos"]), "Cadastros ativos (todas as unidades)"),
        ]
        grade_kpis(self.area, kpis, 3).grid(row=0, column=0, columnspan=2, sticky="ew")
        cartao = Cartao(self.area)
        cartao.grid(row=1, column=0, columnspan=2, sticky="ew", pady=(Espaco.L, 0))
        ctk.CTkLabel(cartao, text="Faturamento por unidade", font=Fonte.corpo,
                     text_color=Cor.TEXTO_SECUNDARIO, anchor="w").pack(fill="x", padx=Espaco.XL,
                                                                        pady=(Espaco.L, 0))
        ctk.CTkLabel(cartao, text=por_un or "—", font=Fonte.h2, text_color=Cor.TEXTO,
                     anchor="w").pack(fill="x", padx=Espaco.XL, pady=(Espaco.XS, Espaco.L))

        self._grafico(2, 0, "Faturamento x custo por unidade", self._colunas, d)
        self._grafico(2, 1, "Faturamento por procedimento", self._rosca, d)
        self._grafico(3, 0, "Faturamento mensal", self._linha, d)
        self._grafico(3, 1, "Pacientes ativos por cidade e bairro", self._barras_cidade, d)

        self._titulo(4, "Retornos pendentes")
        t = Tabela(self.area, [("Paciente", 3, "w"), ("Telefone", 2, "w"),
                               ("Procedimento", 2, "w"), ("Retorno previsto", 2, "w")],
                   "Nenhum retorno pendente.", rolagem=False)
        t.grid(row=5, column=0, columnspan=2, sticky="ew")
        t.preencher([[r["nome_completo"], formatar_telefone(r["telefone_paciente"]),
                      r["nome_procedimento"], formatar_data(r["data_retorno_prevista"])]
                     for r in d["retornos_pendentes"]])
        self._titulo(6, "Alertas de estoque e validade")
        t2 = Tabela(self.area, [("Insumo", 3, "w"), ("Alerta", 3, "w"), ("Saldo", 1, "e")],
                    "Nenhum alerta de estoque.", rolagem=False)
        t2.grid(row=7, column=0, columnspan=2, sticky="ew", pady=(0, Espaco.L))
        alertas = [[e["nome_insumo"], (f"Abaixo do mínimo ({numero(e['estoque_minimo'])})",
                                       Cor.ERRO), f"{numero(e['saldo'])} {e['unidade_medida']}"]
                   for e in d["estoque_alertas"]]
        alertas += [[v["nome_insumo"], ((f"Lote {v['lote']} vencido em "
                                         if v["vencido"] else f"Lote {v['lote']} vence em ")
                                        + formatar_data(v["data_validade"]), Cor.ERRO),
                     f"{numero(v['saldo_insumo'])} {v['unidade_medida']}"]
                    for v in d["validade_alertas"]]
        t2.preencher(alertas)

    def _titulo(self, linha, texto):
        ctk.CTkLabel(self.area, text=texto, font=Fonte.h2, text_color=Cor.TEXTO,
                     anchor="w").grid(row=linha, column=0, columnspan=2, sticky="ew",
                                      pady=(Espaco.XL, Espaco.M))

    # ----- gráficos -----
    def _grafico(self, linha, coluna, titulo, desenhar, d):
        cartao = Cartao(self.area)
        cartao.grid(row=linha, column=coluna, sticky="nsew", pady=(Espaco.L, 0),
                    padx=(0, Espaco.S) if coluna == 0 else (Espaco.S, 0))
        escala = ctk.ScalingTracker.get_widget_scaling(cartao)
        altura = Medida.GRAFICO_ALTURA * escala / Medida.GRAFICO_DPI
        fig = Figure(figsize=(4, altura), dpi=Medida.GRAFICO_DPI)
        ax = fig.add_subplot(111)
        ax.set_title(titulo)
        desenhar(ax, d)
        fig.tight_layout()
        canvas = FigureCanvasTkAgg(fig, master=cartao)
        canvas.draw()
        canvas.get_tk_widget().pack(fill="both", expand=True, padx=Espaco.M, pady=Espaco.M)
        # O matplotlib prende um tratador da roda na janela principal e ele
        # continua ativo depois que a tela muda. Os gráficos não usam a roda;
        # a rolagem é feita pelo tratador único da janela (Janela._rolar).
        self.winfo_toplevel().unbind("<MouseWheel>")
        self._figuras.append(fig)

    def _sem_dados(self, ax):
        ax.text(0.5, 0.5, "Sem dados no período", ha="center", va="center",
                color=Cor.TEXTO_SECUNDARIO, transform=ax.transAxes)
        ax.set_xticks([])
        ax.set_yticks([])

    def _colunas(self, ax, d):
        nomes = [n.replace("Unidade ", "") for n, _ in d["faturamento_por_unidade"]]
        if not nomes:
            return self._sem_dados(ax)
        fat = [float(v) for _, v in d["faturamento_por_unidade"]]
        custo = [float(v) for _, v in d["custo_por_unidade"]]
        x = range(len(nomes))
        largura = Medida.GRAFICO_BARRA
        ax.bar([i - largura / 2 for i in x], fat, largura, color=Cor.OURO, label="Faturamento")
        ax.bar([i + largura / 2 for i in x], custo, largura, color=Cor.TAUPE,
               label="Locação + despesas")
        ax.set_xticks(list(x), nomes)
        ax.yaxis.set_major_formatter(_milhar)
        # espaço livre no topo para a legenda não cobrir as colunas
        ax.set_ylim(0, max(fat + custo + [1]) * Medida.GRAFICO_FOLGA_TOPO)
        ax.legend(frameon=False, loc="upper left", ncol=2,
                  fontsize=Medida.GRAFICO_FONTE_PEQUENA)

    def _rosca(self, ax, d):
        itens = [(n, float(v)) for n, v in d["por_procedimento"] if v and float(v) > 0]
        if not itens:
            return self._sem_dados(ax)
        valores = [v for _, v in itens]
        total = sum(valores)
        ax.pie(valores, colors=Cor.SERIES[:len(valores)], startangle=90, counterclock=False,
               wedgeprops=dict(width=Medida.GRAFICO_ROSCA, edgecolor=Cor.FUNDO))
        ax.legend([f"{n} ({v / total:.0%})".replace(".", ",") for n, v in itens], frameon=False,
                  loc="center left", bbox_to_anchor=(1.0, 0.5), fontsize=Medida.GRAFICO_FONTE_PEQUENA)
        ax.set_aspect("equal")

    def _linha(self, ax, d):
        if not d["mensal"]:
            return self._sem_dados(ax)
        meses = [mes_curto(m) for m, _ in d["mensal"]]
        valores = [float(v) for _, v in d["mensal"]]
        ax.plot(meses, valores, color=Cor.OURO_BOTAO, linewidth=Medida.GRAFICO_LINHA, marker="o",
                markersize=Medida.GRAFICO_MARCADOR)
        ax.yaxis.set_major_formatter(_milhar)
        ax.tick_params(axis="x", labelrotation=45, labelsize=Medida.GRAFICO_FONTE_PEQUENA)
        ax.grid(axis="y", color=Cor.BORDA_SUAVE, linewidth=Medida.DIVISORIA)

    def _barras_cidade(self, ax, d):
        linhas = [c for c in d["cidades"] if c["pacientes_ativos"]][:Medida.GRAFICO_MAX_BAIRROS]
        if not linhas:
            return self._sem_dados(ax)
        rotulos = [f"{c['bairro']} ({c['cidade']})" for c in linhas][::-1]
        valores = [int(c["pacientes_ativos"]) for c in linhas][::-1]
        ax.barh(rotulos, valores, color=Cor.OURO)
        ax.tick_params(axis="y", labelsize=Medida.GRAFICO_FONTE_PEQUENA)
        for i, v in enumerate(valores):
            ax.text(v, i, f" {v}", va="center", fontsize=Medida.GRAFICO_FONTE_PEQUENA, color=Cor.TEXTO)
