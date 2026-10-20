"""Apoio aos testes de interface. Usa só o zenith_teste e apaga o que cria."""
from ferramentas import banco_teste
banco_teste.usar()

import os
import secrets
import tempfile
import time
import traceback
import tkinter

from PIL import ImageGrab

from repositorios.base import consultar, transacao
from servicos import autenticacao

SAIDA = os.path.join(tempfile.gettempdir(), "zenith_capturas")
os.makedirs(SAIDA, exist_ok=True)
PREFIXO = "Teste Fluxo"
_erros_tk = []
tkinter.Tk.report_callback_exception = (
    lambda self, *a: _erros_tk.append("".join(traceback.format_exception(*a))))


class Fluxo:
    def __init__(self, nome):
        self.nome = nome
        self.casos = []
        self.senha = secrets.token_urlsafe(16)
        self.usuarios = {}
        for perfil in ("Gerente", "Atendente", "Profissional"):
            email = f"fluxo.{perfil.lower()}@exemplo.invalid"
            consultar_existente = consultar("SELECT id_usuario FROM usuario WHERE email=%s",
                                            (email,), um=True)
            if consultar_existente:
                self.apagar_usuario(consultar_existente["id_usuario"])
            self.usuarios[perfil] = autenticacao.criar_usuario(
                f"{PREFIXO} {perfil}", email, perfil, self.senha, self.senha,
                id_profissional=1 if perfil == "Profissional" else None)
        from interface.app import Janela
        self.j = Janela()
        self.j.attributes("-topmost", True)
        self.passo(10)

    # utilidades
    def passo(self, n=6):
        for _ in range(n):
            self.j.update()
            time.sleep(0.1)

    def foto(self, nome):
        self.passo()
        self.j.lift()
        self.passo(2)
        x, y = self.j.winfo_rootx(), self.j.winfo_rooty()
        ImageGrab.grab(bbox=(x, y, x + self.j.winfo_width(), y + self.j.winfo_height())
                       ).save(os.path.join(SAIDA, f"{self.nome}_{nome}.png"))

    def ok(self, nome, cond):
        self.casos.append((nome, bool(cond)))

    def tela(self):
        return self.j.area.winfo_children()[0]

    def depois(self, ms, func):
        self.j.after(ms, func)

    def entrar(self, perfil, senha=None):
        login = self.j.raiz
        login.email.definir(f"fluxo.{perfil.lower()}@exemplo.invalid")
        login.senha.definir(self.senha if senha is None else senha)
        login.entrar()
        self.passo()
        return login

    def dialogo(self, classe):
        return next((w for w in self.j.winfo_children() if isinstance(w, classe)), None)

    # limpeza
    def apagar_usuario(self, id_usuario):
        with transacao() as cur:
            cur.execute("DELETE FROM usuario WHERE id_usuario=%s", (id_usuario,))

    def limpar(self, sql_extra=()):
        with transacao() as cur:
            for sql, par in sql_extra:
                cur.execute(sql, par)
            cur.execute("DELETE FROM usuario WHERE nome LIKE %s", (PREFIXO + "%",))
        self.senha = None

    def relatorio(self):
        falhas = 0
        for nome, ok in self.casos:
            falhas += not ok
            print("OK   " if ok else "FALHA", nome)
        for e in _erros_tk:
            falhas += 1
            print("ERRO NA INTERFACE:\n", e)
        print(f"\n{len(self.casos) - sum(not o for _, o in self.casos)}/{len(self.casos)} "
              f"verificações passaram; capturas em {SAIDA}")
        return falhas
