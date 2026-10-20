"""Janela principal: login, menu por perfil e troca de telas."""
from tkinter import TclError

import customtkinter as ctk

from interface import tema
from interface.componentes import BotaoSecundario
from interface.tema import Cor, Espaco, Fonte, Medida, Raio
from interface.telas.atendimentos import TelaAtendimentos
from interface.telas.cadastros import TelaProcedimentos, TelaUnidades
from interface.telas.dashboard import TelaDashboard
from interface.telas.financeiro import TelaFinanceiro
from interface.telas.inicio import TelaInicio
from interface.telas.insumos import TelaInsumos
from interface.telas.login import TelaLogin
from interface.telas.pacientes import TelaPacientes

# (módulo em servicos.permissoes, texto, tela)
MENU = [
    ("inicio", "Início", TelaInicio),
    ("pacientes", "Pacientes", TelaPacientes),
    ("atendimentos", "Atendimentos", TelaAtendimentos),
    ("procedimentos", "Procedimentos", TelaProcedimentos),
    ("unidades", "Unidades", TelaUnidades),
    ("insumos", "Insumos", TelaInsumos),
    ("financeiro", "Financeiro", TelaFinanceiro),
    ("dashboard", "Dashboard", TelaDashboard),
]
VERIFICAR_SESSAO_MS = 30_000
MSG_EXPIROU = "Sua sessão expirou por inatividade. Entre novamente."


class ItemMenu(ctk.CTkFrame):

    def __init__(self, master, texto, comando=None):
        super().__init__(master, fg_color="transparent")
        self.grid_columnconfigure(1, weight=1)
        largura, altura = Medida.MARCADOR_MENU
        self.barra = ctk.CTkFrame(self, width=largura, height=altura, corner_radius=2,
                                  fg_color=Cor.MENU)
        self.barra.grid(row=0, column=0, padx=(0, Espaco.S))
        self.botao = ctk.CTkButton(
            self, text=texto, anchor="w", height=Medida.CONTROLE_ALTURA,
            corner_radius=Raio.ITEM_MENU, font=Fonte.corpo,
            fg_color="transparent", hover_color=Cor.MENU_HOVER,
            text_color=Cor.TEXTO, command=comando)
        self.botao.grid(row=0, column=1, sticky="ew")

    def definir_ativo(self, ativo):
        self.barra.configure(fg_color=Cor.OURO if ativo else Cor.MENU)
        self.botao.configure(
            fg_color=Cor.FUNDO if ativo else "transparent",
            hover_color=Cor.FUNDO if ativo else Cor.MENU_HOVER,
            font=Fonte.corpo_bold if ativo else Fonte.corpo)


class Janela(ctk.CTk):
    def __init__(self):
        ctk.set_appearance_mode("light")
        super().__init__(fg_color=Cor.FUNDO)
        if not tema.preparar(self):
            print("Aviso: arquivos Montserrat não encontrados em assets/fontes; usando a fonte "
                  "do sistema. Baixe a família Montserrat em https://fonts.google.com/specimen/"
                  "Montserrat e copie Light, Regular e Bold (.ttf) para assets/fontes.")
        self.title("Zenith")
        self.geometry(Medida.JANELA)
        self.minsize(*Medida.JANELA_MIN)
        self._definir_icone()
        self.after(0, self._maximizar)
        self.sessao = None
        self.raiz = None
        self.bind_all("<Any-KeyPress>", self._atividade, add="+")
        self.bind_all("<Any-ButtonPress>", self._atividade, add="+")
        # um único tratador da roda para a janela toda (ver AreaRolavel)
        self.bind_all("<MouseWheel>", self._rolar, add="+")
        self.mostrar_login()

    def _maximizar(self):
        try:
            self.state("zoomed")
        except TclError:
            pass

    def _definir_icone(self):
        icone = tema.ASSETS / "icone_app.ico"
        if not icone.exists():
            return

        def aplicar():
            try:
                self.iconbitmap(str(icone))
            except TclError:
                pass
        # o CustomTkinter troca o ícone logo depois de abrir
        self.after(300, aplicar)

    def _trocar_raiz(self, widget):
        if self.raiz is not None:
            self.raiz.destroy()
        self.raiz = widget
        widget.pack(fill="both", expand=True)

    # sessão
    def mostrar_login(self, aviso=""):
        self.sessao = None
        self._trocar_raiz(TelaLogin(self, self.entrou, aviso))

    def entrou(self, sessao):
        self.sessao = sessao
        self._montar_principal()
        self.mostrar("inicio")
        self.after(VERIFICAR_SESSAO_MS, self._verificar_sessao)

    def _rolar(self, evento):
        """Rola a área sob o mouse que ainda pode rolar naquele sentido."""
        self._atividade()
        try:
            alvo = self.winfo_containing(evento.x_root, evento.y_root)
        except (KeyError, TclError):
            return
        escala = ctk.ScalingTracker.get_window_scaling(self)
        deslocamento = -evento.delta / 120 * Medida.ROLAGEM_PASSO * escala
        while alvo is not None:
            canvas = getattr(alvo, "_parent_canvas", None)
            if canvas is not None:
                inicio, fim = canvas.yview()
                caixa = canvas.bbox("all")
                altura = (caixa[3] - caixa[1]) if caixa else 0
                pode = (deslocamento < 0 and inicio > 0) or (deslocamento > 0 and fim < 1)
                if altura and pode:
                    canvas.yview_moveto(min(max(inicio + deslocamento / altura, 0), 1))
                    return "break"
            alvo = getattr(alvo, "master", None)

    def _atividade(self, _evento=None):
        if self.sessao is not None:
            self.sessao.registrar_atividade()

    def _verificar_sessao(self):
        if self.sessao is None:
            return
        if not self.sessao.ativa():
            self.sessao_expirou()
            return
        self.after(VERIFICAR_SESSAO_MS, self._verificar_sessao)

    def sessao_expirou(self):
        if self.sessao is not None:
            self.sessao.encerrar()
        self.mostrar_login(MSG_EXPIROU)

    def sair(self):
        if self.sessao is not None:
            self.sessao.encerrar()
        self.mostrar_login()

    # estrutura principal
    def _montar_principal(self):
        raiz = ctk.CTkFrame(self, fg_color=Cor.FUNDO, corner_radius=0)
        self._trocar_raiz(raiz)
        raiz.grid_columnconfigure(1, weight=1)
        raiz.grid_rowconfigure(0, weight=1)
        self.itens = {}
        self._montar_menu(raiz)
        self.area = ctk.CTkFrame(raiz, fg_color=Cor.FUNDO, corner_radius=0)
        self.area.grid(row=0, column=1, sticky="nsew")
        self.area.grid_columnconfigure(0, weight=1)
        self.area.grid_rowconfigure(0, weight=1)

    def _montar_menu(self, raiz):
        menu = ctk.CTkFrame(raiz, width=Medida.MENU_LARGURA, corner_radius=0, fg_color=Cor.MENU)
        menu.grid(row=0, column=0, sticky="nsw")
        menu.grid_propagate(False)
        menu.grid_columnconfigure(0, weight=1)
        menu.grid_rowconfigure(2, weight=1)

        marca = ctk.CTkFrame(menu, fg_color="transparent")
        marca.grid(row=0, column=0, sticky="ew", padx=Espaco.XL, pady=(Espaco.XL, Espaco.L))
        self.img_marca = tema.imagem("logo_monograma.png", Medida.LOGO_MENU)
        ctk.CTkLabel(marca, image=self.img_marca, text="").pack()
        ctk.CTkLabel(marca, text="Gabriela Saraiva", font=Fonte.marca,
                     text_color=Cor.TEXTO).pack(pady=(Espaco.S, 0))
        ctk.CTkLabel(marca, text="Harmonização orofacial", font=Fonte.pequeno,
                     text_color=Cor.TEXTO_SECUNDARIO).pack()

        nav = ctk.CTkFrame(menu, fg_color="transparent")
        nav.grid(row=1, column=0, sticky="ew", padx=Espaco.L)
        nav.grid_columnconfigure(0, weight=1)
        linha = 0
        for chave, texto, _ in MENU:
            if not self.sessao.pode_ver(chave):
                continue
            item = ItemMenu(nav, texto, comando=lambda c=chave: self.mostrar(c))
            item.grid(row=linha, column=0, sticky="ew", pady=(0, Espaco.XS))
            self.itens[chave] = item
            linha += 1

        rodape = ctk.CTkFrame(menu, fg_color="transparent")
        rodape.grid(row=3, column=0, sticky="ew", padx=Espaco.XL, pady=Espaco.L)
        ctk.CTkLabel(rodape, text=self.sessao.nome, font=Fonte.rotulo, text_color=Cor.TEXTO,
                     anchor="w", wraplength=Medida.RODAPE_MENU_TEXTO, justify="left"
                     ).pack(fill="x")
        ctk.CTkLabel(rodape, text=f"Perfil: {self.sessao.perfil}", font=Fonte.pequeno,
                     text_color=Cor.TEXTO_SECUNDARIO, anchor="w").pack(fill="x")
        BotaoSecundario(rodape, "Sair", self.sair, height=Medida.BOTAO_LINHA_ALTURA
                        ).pack(fill="x", pady=(Espaco.S, Espaco.S))
        ctk.CTkLabel(rodape, text="Informações confidenciais de pacientes.",
                     font=Fonte.pequeno, text_color=Cor.TEXTO_SECUNDARIO, anchor="w",
                     justify="left", wraplength=Medida.RODAPE_MENU_TEXTO).pack(fill="x")

    # navegação
    def mostrar(self, chave):
        if self.sessao is None or not self.sessao.ativa():
            self.sessao_expirou()
            return
        if not self.sessao.pode_ver(chave):
            return
        for k, item in self.itens.items():
            item.definir_ativo(k == chave)
        for w in self.area.winfo_children():
            w.destroy()
        tela = next(classe for c, _, classe in MENU if c == chave)
        tela(self.area, self).grid(row=0, column=0, sticky="nsew")
