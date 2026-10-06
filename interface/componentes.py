"""Componentes visuais reutilizáveis. Todos os valores vêm de tema.py."""
import tkinter as tk

import customtkinter as ctk

from interface import tema
from interface.tema import Cor, Espaco, Raio, Medida, Fonte


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
                         text_color=Cor.OURO_BOTAO, border_width=Medida.DIVISORIA,
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
                        border_width=Medida.DIVISORIA, border_color=Cor.BORDA_CAMPO,
                        fg_color=Cor.FUNDO, text_color=Cor.TEXTO,
                        placeholder_text_color=Cor.TEXTO_DESABILITADO, **kwargs)


class Campo(ctk.CTkFrame):
    """Rótulo em negrito acima, controle no meio, mensagem de erro abaixo.
    Com 'sugestoes', o controle é uma caixa editável com lista de opções."""

    def __init__(self, master, rotulo, dica="", sugestoes=None):
        super().__init__(master, fg_color="transparent")
        self.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(self, text=rotulo, font=Fonte.rotulo, text_color=Cor.TEXTO,
                     anchor="w").grid(row=0, column=0, sticky="ew",
                                      pady=(0, Espaco.XS))

        if sugestoes:
            self.controle = ctk.CTkComboBox(
                self, values=sugestoes, height=Medida.CONTROLE_ALTURA,
                font=Fonte.corpo, dropdown_font=Fonte.corpo,
                corner_radius=Raio.CONTROLE, border_width=Medida.DIVISORIA,
                border_color=Cor.BORDA_CAMPO, button_color=Cor.BORDA_CAMPO,
                button_hover_color=Cor.TEXTO_SECUNDARIO, fg_color=Cor.FUNDO,
                text_color=Cor.TEXTO, dropdown_fg_color=Cor.FUNDO,
                dropdown_hover_color=Cor.MENU_HOVER,
                dropdown_text_color=Cor.TEXTO)
            self.controle.set("")
        else:
            self.controle = entrada(self, placeholder_text=dica)
        self.controle.grid(row=1, column=0, sticky="ew")

        self.erro = ctk.CTkLabel(self, text="", font=Fonte.pequeno,
                                 text_color=Cor.ERRO, anchor="w", justify="left")
        self.erro.grid(row=2, column=0, sticky="ew", pady=(Espaco.XS, 0))
        self.erro.grid_remove()

    def valor(self):
        return self.controle.get()

    def definir(self, texto):
        if isinstance(self.controle, ctk.CTkComboBox):
            self.controle.set(texto)
        else:
            self.controle.delete(0, "end")
            if texto:
                self.controle.insert(0, texto)

    def mostrar_erro(self, texto):
        if texto:
            self.erro.configure(text=texto)
            self.erro.grid()
            self.controle.configure(border_color=Cor.ERRO)
        else:
            self.erro.grid_remove()
            self.controle.configure(border_color=Cor.BORDA_CAMPO)


class DialogoConfirmacao(ctk.CTkToplevel):
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
            self.after(20, self._bloquear_janela_de_tras)

    def _centralizar(self):
        # o CustomTkinter ajusta a escala logo após abrir e o tamanho final
        # só existe depois disso; medimos de novo assim que a janela aparece
        self.update_idletasks()
        self._posicionar(self.winfo_reqwidth(), self.winfo_reqheight())
        self.after(50, lambda: self.winfo_exists() and
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
            self.after(300, lambda: self.winfo_exists() and self.iconbitmap(str(icone)))

    def confirmar(self):
        self.resultado = True
        self._fechar()

    def cancelar(self):
        self.resultado = False
        self._fechar()

    def _fechar(self):
        self.grab_release()
        self.destroy()


def confirmar(master, titulo, texto, rotulo_confirmar):
    """Abre o diálogo e espera a resposta. Retorna True se confirmado."""
    dialogo = DialogoConfirmacao(master, titulo, texto, rotulo_confirmar)
    dialogo.wait_window()
    return dialogo.resultado
