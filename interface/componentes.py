"""Componentes visuais reutilizáveis. Todos os valores vêm de tema.py."""
import tkinter as tk

import customtkinter as ctk
from customtkinter.windows.widgets.core_widget_classes import DropdownMenu

from interface import tema
from interface.tema import Cor, Espaco, Raio, Medida, Fonte


class AgendaSegura:
    """after() que é cancelado quando o widget é destruído. O Tk apaga o
    comando do after junto com o widget; se ele ainda estiver agendado, o
    disparo vira o erro "invalid command name ..."."""

    def agendar(self, ms, funcao):
        ids = self.__dict__.setdefault("_agendados", set())

        def executar():
            ids.discard(ident[0])
            funcao()
        ident = [self.after(ms, executar)]
        ids.add(ident[0])
        return ident[0]

    def cancelar_agendamentos(self):
        for ident in self.__dict__.get("_agendados", set()):
            try:
                self.after_cancel(ident)
            except tk.TclError:
                pass
        self.__dict__.get("_agendados", set()).clear()


class Cartao(ctk.CTkFrame):
    def __init__(self, master, **kwargs):
        super().__init__(master, fg_color=Cor.FUNDO, corner_radius=Raio.CARTAO,
                         border_width=Medida.DIVISORIA,
                         border_color=Cor.BORDA_SUAVE, **kwargs)


class BotaoPrincipal(ctk.CTkButton):
    """Fundo dourado, texto branco em negrito."""

    def __init__(self, master, texto, comando, **kwargs):
        kwargs.setdefault("height", Medida.CONTROLE_ALTURA)
        kwargs.setdefault("width", Medida.BOTAO_LARGURA_MIN)
        super().__init__(master, text=texto, command=comando, font=Fonte.botao,
                         corner_radius=Raio.CONTROLE, fg_color=Cor.OURO_BOTAO,
                         hover_color=Cor.OURO_BOTAO_HOVER,
                         text_color=Cor.SOBRE_OURO, border_width=0, **kwargs)


class BotaoSecundario(ctk.CTkButton):
    """Fundo branco, borda e texto dourados."""

    def __init__(self, master, texto, comando, **kwargs):
        kwargs.setdefault("height", Medida.CONTROLE_ALTURA)
        kwargs.setdefault("width", Medida.BOTAO_LARGURA_MIN)
        super().__init__(master, text=texto, command=comando, font=Fonte.botao,
                         corner_radius=Raio.CONTROLE, fg_color=Cor.FUNDO,
                         hover_color=Cor.SUPERFICIE_SUAVE,
                         text_color=Cor.OURO_BOTAO, border_width=Medida.BORDA_BOTAO,
                         border_color=Cor.OURO_BOTAO, **kwargs)


class Divisoria(ctk.CTkFrame):
    """Linha horizontal de 1 px."""

    def __init__(self, master, **kwargs):
        super().__init__(master, height=Medida.DIVISORIA, corner_radius=0,
                         fg_color=Cor.BORDA_SUAVE, **kwargs)


class Mensagem(ctk.CTkLabel):
    """Linha de aviso para o usuário: erro, sucesso ou vazia."""

    def __init__(self, master, **kwargs):
        super().__init__(master, text="", font=Fonte.corpo, anchor="w",
                         justify="left", text_color=Cor.TEXTO, **kwargs)

    def erro(self, texto):
        self.configure(text=texto, text_color=Cor.ERRO)

    def sucesso(self, texto):
        self.configure(text=texto, text_color=Cor.SUCESSO)

    def limpar(self):
        self.configure(text="")


def entrada(master, **kwargs):
    """Campo de texto padrão, com borda visível."""
    kwargs.setdefault("height", Medida.CONTROLE_ALTURA)
    return ctk.CTkEntry(master, font=Fonte.corpo, corner_radius=Raio.CONTROLE,
                        border_width=Medida.BORDA_CAMPO, border_color=Cor.BORDA_CAMPO,
                        fg_color=Cor.FUNDO, text_color=Cor.TEXTO,
                        placeholder_text_color=Cor.TEXTO_DESABILITADO, **kwargs)


class Campo(ctk.CTkFrame):
    """Rótulo em negrito acima, controle no meio, mensagem de erro abaixo.
    Com 'sugestoes', o controle é uma caixa editável com lista de opções.
    Com 'opcoes' [(valor, rótulo)], é um seletor fechado (valor() devolve o valor).
    Com 'multilinha', é uma caixa de texto de várias linhas."""

    def __init__(self, master, rotulo, dica="", sugestoes=None, opcoes=None,
                 multilinha=False, vazio="Selecione"):
        super().__init__(master, fg_color="transparent")
        self.grid_columnconfigure(0, weight=1)
        self.multilinha = multilinha

        ctk.CTkLabel(self, text=rotulo, font=Fonte.rotulo, text_color=Cor.TEXTO,
                     anchor="w").grid(row=0, column=0, sticky="ew",
                                      pady=(0, Espaco.XS))

        if opcoes is not None:
            self.controle = Seletor(self, opcoes, vazio=vazio)
        elif multilinha:
            self.controle = ctk.CTkTextbox(
                self, height=Medida.CONTROLE_ALTURA * 2, font=Fonte.corpo, wrap="word",
                corner_radius=Raio.CONTROLE, border_width=Medida.BORDA_CAMPO,
                border_color=Cor.BORDA_CAMPO, fg_color=Cor.FUNDO, text_color=Cor.TEXTO)
        elif sugestoes:
            self.controle = CaixaOpcoes(self, [(s, s) for s in sugestoes], editavel=True)
        else:
            self.controle = entrada(self, placeholder_text=dica)
        self.controle.grid(row=1, column=0, sticky="ew")

        self.erro = ctk.CTkLabel(self, text="", font=Fonte.pequeno,
                                 text_color=Cor.ERRO, anchor="w", justify="left")
        self.erro.grid(row=2, column=0, sticky="ew", pady=(Espaco.XS, 0))
        self.erro.grid_remove()

        if dica and (opcoes is not None or multilinha or sugestoes):
            self.mostrar_dica(dica)

    def mostrar_dica(self, texto):
        self.erro.configure(text=texto, text_color=Cor.TEXTO_SECUNDARIO)
        self.erro.grid()
        self._dica = texto

    def valor(self):
        if isinstance(self.controle, CaixaOpcoes):
            return self.controle.valor()
        if self.multilinha:
            return self.controle.get("1.0", "end").strip()
        return self.controle.get()

    def definir(self, texto):
        if isinstance(self.controle, CaixaOpcoes):
            self.controle.definir(texto)
        elif self.multilinha:
            self.controle.delete("1.0", "end")
            if texto:
                self.controle.insert("1.0", texto)
        else:
            self.controle.delete(0, "end")
            if texto:
                self.controle.insert(0, texto)

    def somente_leitura(self):
        self.controle.configure(state="disabled")

    def mostrar_erro(self, texto):
        if texto:
            self.erro.configure(text=texto, text_color=Cor.ERRO)
            self.erro.grid()
            self.controle.configure(border_color=Cor.ERRO)
        else:
            dica = getattr(self, "_dica", "")
            if dica:
                self.erro.configure(text=dica, text_color=Cor.TEXTO_SECUNDARIO)
            else:
                self.erro.grid_remove()
            self.controle.configure(border_color=Cor.BORDA_CAMPO)


class DialogoConfirmacao(AgendaSegura, ctk.CTkToplevel):
    """Diálogo modal de confirmação com o visual do sistema.
    Abre centralizado sobre a janela do programa e bloqueia a janela de trás.
    Enter confirma; Esc ou fechar a janela cancela. Use a função confirmar()."""

    def __init__(self, master, titulo, texto, rotulo_confirmar):
        self.janela = master.winfo_toplevel()
        super().__init__(self.janela, fg_color=Cor.FUNDO)
        self.resultado = False
        self.title(titulo)
        self.resizable(False, False)
        self.transient(self.janela)

        corpo = ctk.CTkFrame(self, fg_color="transparent")
        corpo.pack(padx=Espaco.XL, pady=Espaco.XL)
        ctk.CTkLabel(corpo, text=titulo, font=Fonte.h2, text_color=Cor.TEXTO,
                     anchor="w").pack(fill="x")
        ctk.CTkLabel(corpo, text=texto, font=Fonte.corpo, text_color=Cor.TEXTO,
                     anchor="w", justify="left",
                     wraplength=Medida.DIALOGO_LARGURA
                     ).pack(fill="x", pady=(Espaco.M, Espaco.XL))
        botoes = ctk.CTkFrame(corpo, fg_color="transparent")
        botoes.pack(anchor="e")
        BotaoSecundario(botoes, "Cancelar", self.cancelar).pack(side="left")
        BotaoPrincipal(botoes, rotulo_confirmar, self.confirmar
                       ).pack(side="left", padx=(Espaco.S, 0))

        self.bind("<Return>", lambda _e: self.confirmar())
        self.bind("<KP_Enter>", lambda _e: self.confirmar())
        self.bind("<Escape>", lambda _e: self.cancelar())
        self.protocol("WM_DELETE_WINDOW", self.cancelar)

        self._centralizar()
        self._definir_icone()
        self._bloquear_janela_de_tras()

    def _bloquear_janela_de_tras(self):
        # o grab só funciona depois que o diálogo aparece na tela
        try:
            self.grab_set()
            self.focus_force()
        except tk.TclError:
            self.agendar(20, self._bloquear_janela_de_tras)

    def _centralizar(self):
        # o CustomTkinter ajusta a escala logo após abrir e o tamanho final
        # só existe depois disso; medimos de novo assim que a janela aparece
        self.update_idletasks()
        self._posicionar(self.winfo_reqwidth(), self.winfo_reqheight())
        self.agendar(50, lambda:
                   self._posicionar(self.winfo_width(), self.winfo_height()))

    def _posicionar(self, largura, altura):
        j = self.janela
        # "+x+y" posiciona a moldura (barra de título e borda), não a área
        # interna; descontamos essa diferença, que só é conhecida após abrir
        borda_x = self.winfo_rootx() - self.winfo_x()
        borda_y = self.winfo_rooty() - self.winfo_y()
        x = j.winfo_rootx() + (j.winfo_width() - largura) // 2 - borda_x
        y = j.winfo_rooty() + (j.winfo_height() - altura) // 2 - borda_y
        # só a posição, em pixels reais; o tamanho fica o que o conteúdo pede
        tk.Toplevel.wm_geometry(self, f"+{max(x, 0)}+{max(y, 0)}")

    def _definir_icone(self):
        icone = tema.ASSETS / "icone_app.ico"
        if icone.exists():
            # o CustomTkinter troca o ícone ~200 ms após abrir; aplicamos depois
            self.agendar(300, lambda: self.iconbitmap(str(icone)))

    def confirmar(self):
        self.resultado = True
        self._fechar()

    def cancelar(self):
        self.resultado = False
        self._fechar()

    def _fechar(self):
        self.grab_release()
        self.cancelar_agendamentos()
        self.destroy()


def confirmar(master, titulo, texto, rotulo_confirmar):
    """Abre o diálogo e espera a resposta. Retorna True se confirmado."""
    dialogo = DialogoConfirmacao(master, titulo, texto, rotulo_confirmar)
    dialogo.wait_window()
    return dialogo.resultado


class CaixaOpcoes(ctk.CTkFrame):
    """Caixa de opções desenhada pelo próprio sistema: moldura única com
    borda contínua (a do CustomTkinter cobre a borda com o bloco da seta),
    texto que não é cortado e uma seta em traço fino.

    opcoes = [(valor, rótulo)]. Fechada (padrão): valor() devolve o valor.
    editavel=True: o usuário digita livremente e a lista só sugere textos.
    """

    def __init__(self, master, opcoes, vazio="Selecione", comando=None, editavel=False,
                 width=None, height=None, **_ignorado):
        altura = height or Medida.CONTROLE_ALTURA
        kwargs = dict(width=width) if width else {}
        super().__init__(master, height=altura, corner_radius=Raio.CONTROLE,
                         border_width=Medida.BORDA_CAMPO, border_color=Cor.BORDA_CAMPO,
                         fg_color=Cor.FUNDO, **kwargs)
        # a moldura mantém a própria altura; sem isso ela encolhe até o texto
        # e o texto cobre a borda de cima e de baixo
        self.grid_propagate(False)
        self._vazio, self._comando, self._editavel = vazio, comando, editavel
        self._estado = "normal"
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(0, weight=1)
        margem = Medida.BORDA_CAMPO + Espaco.XS
        if editavel:
            self.texto = ctk.CTkEntry(self, font=Fonte.corpo, border_width=0, fg_color=Cor.FUNDO,
                                      text_color=Cor.TEXTO, height=altura - 2 * margem,
                                      corner_radius=0)
            self.texto.grid(row=0, column=0, sticky="ew", padx=(margem, 0))
        else:
            self.texto = ctk.CTkLabel(self, text=vazio, font=Fonte.corpo, text_color=Cor.TEXTO,
                                      anchor="w", height=altura - 2 * margem, cursor="hand2")
            self.texto.grid(row=0, column=0, sticky="ew", padx=(Espaco.M, 0))
            self.texto.bind("<Button-1>", self._abrir)
        self.seta = tk.Canvas(self, width=Medida.SETA_LARGURA, height=Medida.SETA_LARGURA,
                              bg=Cor.FUNDO, highlightthickness=0, cursor="hand2")
        self.seta.grid(row=0, column=1, padx=(Espaco.XS, Espaco.M))
        self.seta.bind("<Button-1>", self._abrir)
        self.bind("<Button-1>", self._abrir)
        self.bind("<Configure>", lambda _e: self._desenhar_seta(), add="+")
        self.menu = DropdownMenu(self, fg_color=Cor.FUNDO, hover_color=Cor.MENU_HOVER,
                                 text_color=Cor.TEXTO, font=Fonte.corpo, values=[],
                                 command=self._escolheu)
        self.trocar_opcoes(opcoes)

    # ----- desenho -----
    def _desenhar_seta(self):
        c = self.seta
        c.delete("all")
        escala = ctk.ScalingTracker.get_widget_scaling(self)
        lado = Medida.SETA_LARGURA * escala
        c.configure(width=lado, height=lado)
        cor = Cor.TEXTO_DESABILITADO if self._estado == "disabled" else Cor.TEXTO_SECUNDARIO
        m = lado * 0.25
        c.create_line(m, lado * 0.38, lado / 2, lado * 0.62, lado - m, lado * 0.38,
                      fill=cor, width=max(1.5, escala * 1.5), capstyle="round",
                      joinstyle="round")

    # ----- opções -----
    def trocar_opcoes(self, opcoes):
        self._opcoes = [] if self._editavel else [(None, self._vazio)]
        self._opcoes += [(v, str(r)) for v, r in opcoes]
        self._por_rotulo = {r: v for v, r in self._opcoes}
        self.menu.configure(values=[r for _, r in self._opcoes])
        self._mostrar(None if not self._editavel else "")

    def _mostrar(self, valor):
        if self._editavel:
            self.texto.delete(0, "end")
            if valor:
                self.texto.insert(0, valor)
            return
        rotulo = next((r for v, r in self._opcoes
                       if v == valor or (v is not None and str(v) == str(valor))), self._vazio)
        self._atual = self._por_rotulo.get(rotulo)
        self.texto.configure(text=rotulo, text_color=Cor.TEXTO_SECUNDARIO
                             if self._atual is None else Cor.TEXTO)

    def _abrir(self, _evento=None):
        if self._estado == "disabled":
            return
        self.menu.open(self.winfo_rootx(),
                       self.winfo_rooty() + self.winfo_height() + Espaco.XS)

    def _escolheu(self, rotulo):
        if rotulo is not None:          # None: só dispara o comando com o valor atual
            if self._editavel:
                self._mostrar(rotulo)
            else:
                self._mostrar(self._por_rotulo.get(rotulo))
        if self._comando:
            self._comando(self.valor())

    # ----- interface usada pelas telas -----
    def valor(self):
        return self.texto.get() if self._editavel else self._atual

    def get(self):
        return self.texto.get() if self._editavel else self.texto.cget("text")

    def definir(self, valor):
        self._mostrar(valor)

    set = definir

    def configure(self, require_redraw=False, **kwargs):
        if "state" in kwargs:
            self._estado = kwargs.pop("state")
            if self._editavel:
                self.texto.configure(state=self._estado)
            self._desenhar_seta()
        super().configure(require_redraw, **kwargs)


class Seletor(CaixaOpcoes):
    """Lista fechada de opções [(valor, rótulo)]. valor() devolve o valor
    escolhido (ou None na opção vazia)."""


class Cabecalho(ctk.CTkFrame):
    """Título leve, subtítulo e traço dourado de assinatura."""

    def __init__(self, master, titulo, subtitulo=""):
        super().__init__(master, fg_color="transparent")
        self.titulo = ctk.CTkLabel(self, text=titulo, font=Fonte.h1, text_color=Cor.TEXTO,
                                   anchor="w")
        self.titulo.pack(fill="x")
        self.subtitulo = ctk.CTkLabel(self, text=subtitulo, font=Fonte.corpo,
                                      text_color=Cor.TEXTO_SECUNDARIO, anchor="w")
        if subtitulo:
            self.subtitulo.pack(fill="x", pady=(Espaco.XS, 0))
        self.traco = ctk.CTkFrame(self, width=Medida.TRACO_LARGURA, height=Medida.TRACO_ALTURA,
                                  corner_radius=1, fg_color=Cor.OURO)
        self.traco.pack(anchor="w", pady=(Espaco.M, 0))

    def trocar(self, titulo, subtitulo=""):
        self.titulo.configure(text=titulo)
        self.subtitulo.configure(text=subtitulo)
        if subtitulo:
            self.subtitulo.pack(fill="x", pady=(Espaco.XS, 0), after=self.titulo)
        else:
            self.subtitulo.pack_forget()


class Abas(ctk.CTkFrame):
    """Abas de texto: a ativa fica em negrito com sublinhado dourado.
    abas = [(chave, rótulo)]; ao_trocar(chave) é chamado no clique."""

    def __init__(self, master, abas, ao_trocar, ativa=None):
        super().__init__(master, fg_color="transparent")
        self._ao_trocar = ao_trocar
        self._botoes, self._tracos = {}, {}
        for coluna, (chave, rotulo) in enumerate(abas):
            caixa = ctk.CTkFrame(self, fg_color="transparent", width=1, height=1)
            caixa.grid(row=0, column=coluna, padx=(0, Espaco.XL), sticky="s")
            # rótulo clicável: a aba tem a largura do texto (botão teria largura mínima)
            botao = ctk.CTkLabel(caixa, text=rotulo, font=Fonte.corpo,
                                 text_color=Cor.TEXTO_SECUNDARIO, cursor="hand2")
            botao.pack(pady=(Espaco.S, Espaco.M))
            botao.bind("<Button-1>", lambda _e, c=chave: self.ativar(c, avisar=True))
            # width=1: o traço acompanha a largura do texto (o padrão seria 200 px)
            traco = ctk.CTkFrame(caixa, width=1, height=Medida.ABA_TRACO, corner_radius=0,
                                 fg_color=Cor.FUNDO)
            traco.pack(fill="x")
            self._botoes[chave], self._tracos[chave] = botao, traco
        Divisoria(self).grid(row=1, column=0, columnspan=len(abas) + 1, sticky="ew")
        self.grid_columnconfigure(len(abas), weight=1)
        self.ativa = None
        self.ativar(ativa or abas[0][0])

    def ativar(self, chave, avisar=False):
        self.ativa = chave
        for c, botao in self._botoes.items():
            sel = c == chave
            botao.configure(font=Fonte.corpo_bold if sel else Fonte.corpo,
                            text_color=Cor.TEXTO if sel else Cor.TEXTO_SECUNDARIO)
            self._tracos[c].configure(fg_color=Cor.OURO if sel else Cor.FUNDO)
        if avisar:
            self._ao_trocar(chave)


class CartaoKpi(Cartao):
    """Indicador: rótulo, valor grande e nota."""

    def __init__(self, master, rotulo, valor, nota="", cor_nota=None):
        super().__init__(master)
        ctk.CTkLabel(self, text=rotulo, font=Fonte.corpo, text_color=Cor.TEXTO_SECUNDARIO,
                     anchor="w").pack(fill="x", padx=Espaco.XL, pady=(Espaco.L, 0))
        ctk.CTkLabel(self, text=valor, font=Fonte.kpi, text_color=Cor.TEXTO,
                     anchor="w").pack(fill="x", padx=Espaco.XL)
        ctk.CTkLabel(self, text=nota or " ", font=Fonte.pequeno,
                     text_color=cor_nota or Cor.TEXTO_SECUNDARIO, anchor="w", justify="left"
                     ).pack(fill="x", padx=Espaco.XL, pady=(0, Espaco.L))


def grade_kpis(master, kpis, colunas=3):
    """kpis = [(rótulo, valor, nota)]. Devolve o frame com os cartões em grade."""
    grade = ctk.CTkFrame(master, fg_color="transparent")
    for c in range(colunas):
        grade.grid_columnconfigure(c, weight=1, uniform="kpi")
    for i, (rotulo, valor, nota) in enumerate(kpis):
        linha, coluna = divmod(i, colunas)
        CartaoKpi(grade, rotulo, valor, nota).grid(
            row=linha, column=coluna, sticky="nsew",
            padx=(0 if coluna == 0 else Espaco.L, 0), pady=(0 if linha == 0 else Espaco.L, 0))
    return grade


class Barras(Cartao):
    """Barras horizontais pareadas por grupo (ex.: faturamento x custo por
    unidade). grupos = [(nome, [(rótulo, valor, cor, texto_valor)])]."""

    def __init__(self, master, grupos):
        super().__init__(master)
        maximo = max([float(v) for _, linhas in grupos for _, v, _, _ in linhas] + [1.0])
        corpo = ctk.CTkFrame(self, fg_color="transparent")
        corpo.pack(fill="x", padx=Espaco.XL, pady=Espaco.XL)
        corpo.grid_columnconfigure(1, weight=1)
        linha = 0
        for nome, itens in grupos:
            ctk.CTkLabel(corpo, text=nome, font=Fonte.corpo_bold, text_color=Cor.TEXTO,
                         anchor="w").grid(row=linha, column=0, columnspan=3, sticky="w",
                                          pady=(0 if linha == 0 else Espaco.L, Espaco.XS))
            linha += 1
            for rotulo, valor, cor, texto in itens:
                ctk.CTkLabel(corpo, text=rotulo, font=Fonte.pequeno, anchor="w",
                             text_color=Cor.TEXTO).grid(row=linha, column=0, sticky="w",
                                                        padx=(0, Espaco.M))
                trilho = ctk.CTkFrame(corpo, height=Espaco.M, corner_radius=Espaco.M // 2,
                                      fg_color=Cor.SUPERFICIE_SUAVE)
                trilho.grid(row=linha, column=1, sticky="ew", pady=Espaco.XS)
                if float(valor) > 0:
                    ctk.CTkFrame(trilho, corner_radius=Espaco.M // 2, fg_color=cor,
                                 height=Espaco.M).place(relx=0, rely=0, relheight=1,
                                                        relwidth=float(valor) / maximo)
                ctk.CTkLabel(corpo, text=texto, font=Fonte.pequeno, text_color=Cor.TEXTO,
                             anchor="e").grid(row=linha, column=2, sticky="e",
                                              padx=(Espaco.M, 0))
                linha += 1


class Tabela(Cartao):
    """Tabela sem zebra, cabeçalho em superfície suave, linhas de altura fixa,
    divisórias de 1 px e estado vazio. Mostra as linhas em páginas, para não
    criar milhares de controles de uma vez.

    colunas = [(título, peso, alinhamento "w" ou "e")]
    linhas  = [[texto ou (texto, cor) por coluna]]
    acoes   = função(dado_da_linha) -> [(rótulo, comando)] na última coluna
    """

    POR_PAGINA = 25

    def __init__(self, master, colunas, vazio="Nenhum registro encontrado.", acoes=None,
                 rolagem=True):
        super().__init__(master)
        self.colunas = colunas
        self.vazio = vazio
        self.acoes = acoes
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(0, weight=1)
        if rolagem:
            self.corpo = caixa_rolagem(self)
        else:
            self.corpo = ctk.CTkFrame(self, fg_color=Cor.FUNDO, corner_radius=0)
        self.corpo.grid(row=0, column=0, sticky="nsew",
                        padx=Raio.CARTAO // 2, pady=Raio.CARTAO // 2)
        self._linhas, self._dados, self._mostradas = [], [], 0
        self._botao_mais = None

    @property
    def _total(self):
        return len(self.colunas) + (1 if self.acoes else 0)

    def preencher(self, linhas, dados=None, vazio=None):
        for w in self.corpo.winfo_children():
            w.destroy()
        self._botao_mais = None
        self._linhas, self._dados = linhas, (dados if dados is not None else linhas)
        self._mostradas = 0
        for c in range(self._total + 1):
            self.corpo.grid_columnconfigure(c, weight=0, minsize=0)
        if not linhas:
            self.corpo.grid_columnconfigure(0, weight=1)
            ctk.CTkLabel(self.corpo, text=vazio or self.vazio, font=Fonte.corpo,
                         text_color=Cor.TEXTO_SECUNDARIO).grid(row=0, column=0,
                                                               pady=Espaco.XXXL)
            return
        for c, (_, peso, _) in enumerate(self.colunas):
            self.corpo.grid_columnconfigure(c, weight=peso)
        self.corpo.grid_rowconfigure(0, minsize=Medida.LINHA_TABELA)
        ctk.CTkFrame(self.corpo, fg_color=Cor.SUPERFICIE_SUAVE, corner_radius=0,
                     height=Medida.LINHA_TABELA).grid(row=0, column=0, columnspan=self._total,
                                                     sticky="nsew")
        cab = [(t, a) for t, _, a in self.colunas] + ([("", "e")] if self.acoes else [])
        for c, (titulo, alinha) in enumerate(cab):
            self._celula(0, c, titulo, Fonte.rotulo, Cor.TEXTO, Cor.SUPERFICIE_SUAVE, alinha)
        self._mais()

    def _celula(self, linha, coluna, texto, fonte, cor, fundo, alinha):
        ctk.CTkLabel(self.corpo, text=texto, font=fonte, text_color=cor, anchor=alinha,
                     fg_color=fundo).grid(
            row=linha, column=coluna, sticky="ew",
            padx=(Espaco.L, Espaco.L if coluna == self._total - 1 else 0))

    def _mais(self):
        if self._botao_mais is not None:
            self._botao_mais.destroy()
            self._botao_mais = None
        inicio = self._mostradas
        fim = min(inicio + self.POR_PAGINA, len(self._linhas))
        for i in range(inicio, fim):
            linha = 2 * i + 2
            if i > 0:
                Divisoria(self.corpo).grid(row=linha - 1, column=0, columnspan=self._total,
                                           sticky="ew")
            self.corpo.grid_rowconfigure(linha, minsize=Medida.LINHA_TABELA)
            for c, valor in enumerate(self._linhas[i]):
                texto, cor = valor if isinstance(valor, tuple) else (valor, Cor.TEXTO)
                texto = "" if texto is None else str(texto)
                if len(texto) > Medida.TEXTO_MAX_TABELA:
                    texto = texto[:Medida.TEXTO_MAX_TABELA - 3].rstrip() + "..."
                self._celula(linha, c, texto, Fonte.corpo, cor, Cor.FUNDO, self.colunas[c][2])
            if self.acoes:
                caixa = ctk.CTkFrame(self.corpo, fg_color="transparent")
                caixa.grid(row=linha, column=self._total - 1, sticky="e", padx=Espaco.L)
                for n, (rotulo, comando) in enumerate(self.acoes(self._dados[i])):
                    BotaoSecundario(caixa, rotulo, comando, height=Medida.BOTAO_LINHA_ALTURA,
                                    width=Medida.BOTAO_LINHA_LARGURA
                                    ).pack(side="left", padx=(0 if n == 0 else Espaco.S, 0))
        self._mostradas = fim
        if fim < len(self._linhas):
            self._botao_mais = BotaoSecundario(
                self.corpo, f"Mostrar mais ({len(self._linhas) - fim} restantes)", self._mais,
                height=Medida.BOTAO_LINHA_ALTURA)
            self._botao_mais.grid(row=2 * fim + 2, column=0, columnspan=self._total,
                                  pady=Espaco.L)


class RodapeFormulario(ctk.CTkFrame):
    """Rodapé fixo do formulário: divisória, mensagem à esquerda e botões
    Cancelar (secundário) e Salvar (principal) à direita."""

    def __init__(self, master, ao_cancelar, ao_salvar, rotulo_salvar="Salvar",
                 somente_leitura=False):
        super().__init__(master, fg_color=Cor.FUNDO, corner_radius=0)
        Divisoria(self).pack(fill="x")
        linha = ctk.CTkFrame(self, fg_color="transparent")
        linha.pack(fill="x", padx=Espaco.XXL, pady=Espaco.L)
        linha.grid_columnconfigure(0, weight=1)
        self.mensagem = Mensagem(linha)
        self.mensagem.grid(row=0, column=0, sticky="ew", padx=(0, Espaco.L))
        self.salvar = None
        if somente_leitura:
            BotaoSecundario(linha, "Voltar", ao_cancelar).grid(row=0, column=1)
            return
        BotaoSecundario(linha, "Cancelar", ao_cancelar).grid(row=0, column=1,
                                                              padx=(0, Espaco.S))
        self.salvar = BotaoPrincipal(linha, rotulo_salvar, ao_salvar)
        self.salvar.grid(row=0, column=2)


class AreaRolavel(ctk.CTkFrame):
    """Área com rolagem vertical, no lugar do CTkScrollableFrame.

    O componente do CustomTkinter registra tratadores GLOBAIS (bind_all) da
    roda e da tecla Shift a cada instância e nunca os remove: a cada troca de
    tela eles se acumulam, inclusive os de telas já destruídas. Esta área não
    registra nada global; a roda é tratada uma única vez pela janela
    (Janela._rolar), que acha a área sob o mouse pelo atributo _parent_canvas.

    O objeto devolvido é a moldura INTERNA (onde os filhos são colocados);
    grid/pack/destroy agem na moldura externa, como no componente original.
    """

    def __init__(self, master):
        self._externo = ctk.CTkFrame(master, fg_color=Cor.FUNDO, corner_radius=0)
        self._externo.grid_columnconfigure(0, weight=1)
        self._externo.grid_rowconfigure(0, weight=1)
        canvas = tk.Canvas(self._externo, bg=Cor.FUNDO, highlightthickness=0, bd=0)
        canvas.grid(row=0, column=0, sticky="nsew")
        self._barra = ctk.CTkScrollbar(self._externo, command=canvas.yview,
                                       fg_color="transparent",
                                       button_color=Cor.BORDA_SUAVE,
                                       button_hover_color=Cor.BORDA_CAMPO)
        self._barra.grid(row=0, column=1, sticky="ns")
        canvas.configure(yscrollcommand=self._posicao)
        super().__init__(canvas, fg_color=Cor.FUNDO, corner_radius=0)
        self._parent_canvas = canvas
        self._janela = canvas.create_window(0, 0, window=self, anchor="nw")
        canvas.bind("<Configure>", self._ajustar_largura)
        tk.Misc.bind(self, "<Configure>", self._atualizar_regiao, "+")

    def _ajustar_largura(self, evento=None):
        # a moldura interna acompanha a largura visível da área
        self._parent_canvas.itemconfigure(self._janela,
                                          width=self._parent_canvas.winfo_width())

    def _atualizar_regiao(self, evento=None):
        self._parent_canvas.configure(scrollregion=self._parent_canvas.bbox("all"))

    def _posicao(self, inicio, fim):
        self._barra.set(inicio, fim)
        # a barra só aparece quando há o que rolar
        if float(inicio) <= 0 and float(fim) >= 1:
            self._barra.grid_remove()
        else:
            self._barra.grid()

    # posicionamento e destruição agem na moldura externa
    def grid(self, **kwargs):
        self._externo.grid(**kwargs)

    def pack(self, **kwargs):
        self._externo.pack(**kwargs)

    def place(self, **kwargs):
        self._externo.place(**kwargs)

    def grid_remove(self):
        self._externo.grid_remove()

    def grid_forget(self):
        self._externo.grid_forget()

    def pack_forget(self):
        self._externo.pack_forget()

    def destroy(self):
        externo = self._externo
        super().destroy()
        externo.destroy()


def caixa_rolagem(master):
    """Área com rolagem vertical no fundo branco (corpo de formulários e tabelas)."""
    return AreaRolavel(master)


def caixa_selecao(master, texto, variavel, comando):
    return ctk.CTkCheckBox(
        master, text=texto, variable=variavel, command=comando, font=Fonte.corpo,
        text_color=Cor.TEXTO, fg_color=Cor.OURO_BOTAO, hover_color=Cor.OURO_BOTAO_HOVER,
        border_color=Cor.BORDA_CAMPO, checkmark_color=Cor.SOBRE_OURO,
        border_width=Medida.BORDA_CAIXA_SELECAO, corner_radius=Raio.CAIXA_SELECAO)
