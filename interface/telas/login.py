"""Tela de login: cartão centralizado com o monograma, E-mail, Senha e Entrar."""
import customtkinter as ctk

from interface import tema
from interface.componentes import AgendaSegura, BotaoPrincipal, Campo, Mensagem
from interface.tema import Cor, Espaco, Fonte, Medida, Raio
from servicos import autenticacao
from servicos.erros import ErroNegocio


class TelaLogin(AgendaSegura, ctk.CTkFrame):
    def __init__(self, master, ao_entrar, aviso=""):
        super().__init__(master, fg_color=Cor.FUNDO_LOGIN, corner_radius=0)
        self.ao_entrar = ao_entrar
        cartao = ctk.CTkFrame(self, fg_color=Cor.FUNDO, corner_radius=Raio.CARTAO,
                              border_width=Medida.DIVISORIA, border_color=Cor.BORDA_SUAVE,
                              width=Medida.LOGIN_LARGURA)
        cartao.place(relx=0.5, rely=0.5, anchor="center")
        corpo = ctk.CTkFrame(cartao, fg_color="transparent", width=Medida.LOGIN_LARGURA)
        corpo.pack(padx=Espaco.XXL, pady=Espaco.XXL)
        self.logo = tema.imagem("logo_monograma.png", Medida.LOGO_LOGIN)
        ctk.CTkLabel(corpo, image=self.logo, text="").pack()
        ctk.CTkLabel(corpo, text="Zenith", font=Fonte.h1, text_color=Cor.TEXTO
                     ).pack(pady=(Espaco.M, 0))
        ctk.CTkLabel(corpo, text="Gabriela Saraiva · Harmonização orofacial",
                     font=Fonte.pequeno, text_color=Cor.TEXTO_SECUNDARIO).pack()
        ctk.CTkFrame(corpo, width=Medida.TRACO_LARGURA, height=Medida.TRACO_ALTURA,
                     corner_radius=1, fg_color=Cor.OURO).pack(pady=(Espaco.M, Espaco.L))
        self.email = Campo(corpo, "E-mail", dica="seu@email.com")
        self.email.pack(fill="x")
        self.senha = Campo(corpo, "Senha")
        self.senha.controle.configure(show="•")
        self.senha.pack(fill="x", pady=(Espaco.M, 0))
        self.botao = BotaoPrincipal(corpo, "Entrar", self.entrar,
                                    width=Medida.LOGIN_LARGURA - 2 * Espaco.XXL)
        self.botao.pack(fill="x", pady=(Espaco.L, 0))
        self.mensagem = Mensagem(corpo, wraplength=Medida.LOGIN_LARGURA - 2 * Espaco.XXL)
        self.mensagem.pack(fill="x", pady=(Espaco.S, 0))
        if aviso:
            self.mensagem.erro(aviso)
        for campo in (self.email, self.senha):
            campo.controle.bind("<Return>", lambda _e: self.entrar())
        self.agendar(100, lambda: self.email.controle.focus_set())

    def destroy(self):
        self.cancelar_agendamentos()
        super().destroy()

    def entrar(self):
        self.mensagem.limpar()
        try:
            sessao = autenticacao.entrar(self.email.valor(), self.senha.valor())
        except ErroNegocio as erro:
            self.senha.definir("")
            self.mensagem.erro(erro.mensagem)
            return
        self.senha.definir("")
        self.ao_entrar(sessao)
