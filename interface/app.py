from tkinter import TclError

import customtkinter as ctk

from interface import tema
from interface.tema import Cor, Espaco, Raio, Medida, Fonte
from interface.componentes import Cartao
from interface.telas.pacientes import TelaPacientes
from repositorios import paciente as repo_paciente

# (chave, texto, em_breve)
MENU = [
    ("inicio", "Início", False),
    ("pacientes", "Pacientes", False),
    ("atendimentos", "Atendimentos", True),
    ("procedimentos", "Procedimentos", True),
    ("unidades", "Unidades", True),
    ("insumos", "Insumos", True),
    ("financeiro", "Financeiro", True),
]


class ItemMenu(ctk.CTkFrame):
    """Item do menu lateral. O estado ativo não depende só da cor:
    fundo branco, texto em negrito e marcador dourado."""

    def __init__(self, master, texto, comando=None, em_breve=False):
        super().__init__(master, fg_color="transparent")
        self.grid_columnconfigure(1, weight=1)

        self.barra = ctk.CTkFrame(self, width=3, height=24, corner_radius=2,
                                  fg_color=Cor.MENU)
        self.barra.grid(row=0, column=0, padx=(0, Espaco.S))

        self.botao = ctk.CTkButton(
            self, text=texto, anchor="w", height=Medida.CONTROLE_ALTURA,
            corner_radius=Raio.ITEM_MENU, font=Fonte.corpo,
            fg_color="transparent", hover_color=Cor.MENU_HOVER,
            text_color=Cor.TEXTO, text_color_disabled=Cor.TEXTO_DESABILITADO,
            command=comando, state="disabled" if em_breve else "normal",
        )
        self.botao.grid(row=0, column=1, sticky="ew")

        if em_breve:
            ctk.CTkLabel(self, text="em breve", font=Fonte.pequeno,
                         text_color=Cor.TEXTO_SECUNDARIO
                         ).grid(row=0, column=1, sticky="e", padx=Espaco.M)

    def definir_ativo(self, ativo):
        self.barra.configure(fg_color=Cor.OURO if ativo else Cor.MENU)
        self.botao.configure(
            fg_color=Cor.FUNDO if ativo else "transparent",
            hover_color=Cor.FUNDO if ativo else Cor.MENU_HOVER,
            font=Fonte.corpo_bold if ativo else Fonte.corpo,
        )


class Janela(ctk.CTk):
    def __init__(self):
        ctk.set_appearance_mode("light")
        super().__init__(fg_color=Cor.FUNDO)
        if not tema.preparar(self):
            print("Aviso: Montserrat não encontrada em assets/fontes; "
                  "usando a fonte do sistema.")

        self.title("Zenith")
        self.geometry(Medida.JANELA)
        self.minsize(*Medida.JANELA_MIN)
        self._definir_icone()

        self.itens = {}
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)
        self._montar_menu()

        self.area = ctk.CTkFrame(self, fg_color=Cor.FUNDO, corner_radius=0)
        self.area.grid(row=0, column=1, sticky="nsew")
        self.mostrar("inicio")

    # ---------- estrutura ----------
    def _definir_icone(self):
        icone = tema.ASSETS / "icone_app.ico"
        if not icone.exists():
            return

        def aplicar():
            try:
                self.iconbitmap(str(icone))
            except TclError:
                pass
        # o CustomTkinter troca o ícone ~200 ms após abrir; aplicamos depois
        self.after(300, aplicar)

    def _montar_menu(self):
        menu = ctk.CTkFrame(self, width=Medida.MENU_LARGURA, corner_radius=0,
                            fg_color=Cor.MENU)
        menu.grid(row=0, column=0, sticky="nsw")
        menu.grid_propagate(False)
        menu.grid_columnconfigure(0, weight=1)
        menu.grid_rowconfigure(2, weight=1)

        marca = ctk.CTkFrame(menu, fg_color="transparent")
        marca.grid(row=0, column=0, sticky="ew", padx=Espaco.XL,
                   pady=(Espaco.XXL, Espaco.XL))
        self.img_marca = tema.imagem("logo_monograma.png", 76)
        ctk.CTkLabel(marca, image=self.img_marca, text="").pack()
        ctk.CTkLabel(marca, text="Gabriela Saraiva", font=Fonte.marca,
                     text_color=Cor.TEXTO).pack(pady=(Espaco.M, 0))
        ctk.CTkLabel(marca, text="Harmonização orofacial", font=Fonte.pequeno,
                     text_color=Cor.TEXTO_SECUNDARIO).pack()

        nav = ctk.CTkFrame(menu, fg_color="transparent")
        nav.grid(row=1, column=0, sticky="ew", padx=Espaco.L)
        nav.grid_columnconfigure(0, weight=1)
        for linha, (chave, texto, em_breve) in enumerate(MENU):
            item = ItemMenu(nav, texto, em_breve=em_breve,
                            comando=lambda c=chave: self.mostrar(c))
            item.grid(row=linha, column=0, sticky="ew", pady=(0, Espaco.XS))
            self.itens[chave] = item

        rodape = ctk.CTkFrame(menu, fg_color="transparent")
        rodape.grid(row=3, column=0, sticky="ew", padx=Espaco.XL,
                    pady=Espaco.XL)
        ctk.CTkLabel(rodape, text="Zenith", font=Fonte.rotulo,
                     text_color=Cor.TEXTO_SECUNDARIO, anchor="w"
                     ).pack(fill="x")
        ctk.CTkLabel(rodape, text="Informações confidenciais de pacientes.",
                     font=Fonte.pequeno, text_color=Cor.TEXTO_SECUNDARIO,
                     anchor="w", justify="left", wraplength=190
                     ).pack(fill="x", pady=(Espaco.XS, 0))

    # ---------- navegação ----------
    def mostrar(self, chave):
        for k, item in self.itens.items():
            item.definir_ativo(k == chave)
        for w in self.area.winfo_children():
            w.destroy()
        {"inicio": self._tela_inicio,
         "pacientes": self._tela_pacientes}[chave]()

    def _cabecalho(self, titulo, subtitulo):
        topo = ctk.CTkFrame(self.area, fg_color="transparent")
        topo.pack(fill="x", padx=Espaco.XXXL, pady=(Espaco.XXXL, Espaco.XL))
        ctk.CTkLabel(topo, text=titulo, font=Fonte.h1, text_color=Cor.TEXTO,
                     anchor="w").pack(fill="x")
        ctk.CTkLabel(topo, text=subtitulo, font=Fonte.corpo,
                     text_color=Cor.TEXTO_SECUNDARIO, anchor="w"
                     ).pack(fill="x", pady=(Espaco.XS, 0))
        # traço dourado de assinatura
        ctk.CTkFrame(topo, width=48, height=2, corner_radius=1,
                     fg_color=Cor.OURO).pack(anchor="w", pady=(Espaco.M, 0))

    # ---------- telas ----------
    def _tela_inicio(self):
        self._cabecalho("Início", "Visão geral do consultório")
        grade = ctk.CTkFrame(self.area, fg_color="transparent")
        grade.pack(fill="x", padx=Espaco.XXXL)
        for c in range(3):
            grade.grid_columnconfigure(c, weight=1, uniform="cartao")

        try:
            total, aviso, cor_aviso = str(len(repo_paciente.listar())), "", None
        except (ConnectionError, RuntimeError):
            total, aviso, cor_aviso = "—", "Banco de dados indisponível", Cor.ERRO

        self._cartao(grade, 0, "Pacientes ativos", total, aviso, cor_aviso)
        self._cartao(grade, 1, "Próximos atendimentos", "—", "Disponível em breve")
        self._cartao(grade, 2, "Pacientes a retornar", "—", "Disponível em breve")

    def _cartao(self, pai, coluna, rotulo, valor, nota="", cor_nota=None):
        cartao = Cartao(pai)
        cartao.grid(row=0, column=coluna, sticky="nsew",
                    padx=(0 if coluna == 0 else Espaco.L, 0))
        ctk.CTkLabel(cartao, text=rotulo, font=Fonte.corpo,
                     text_color=Cor.TEXTO_SECUNDARIO, anchor="w"
                     ).pack(fill="x", padx=Espaco.XL, pady=(Espaco.XL, 0))
        ctk.CTkLabel(cartao, text=valor, font=Fonte.kpi, text_color=Cor.TEXTO,
                     anchor="w").pack(fill="x", padx=Espaco.XL)
        ctk.CTkLabel(cartao, text=nota or " ", font=Fonte.pequeno,
                     text_color=cor_nota or Cor.TEXTO_SECUNDARIO, anchor="w"
                     ).pack(fill="x", padx=Espaco.XL, pady=(0, Espaco.XL))

    def _tela_pacientes(self):
        self._cabecalho("Pacientes", "Cadastro e consulta de pacientes")
        TelaPacientes(self.area).pack(fill="both", expand=True,
                                      padx=Espaco.XXXL, pady=(0, Espaco.XXL))
