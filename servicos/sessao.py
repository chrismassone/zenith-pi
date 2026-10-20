"""Sessão em memória com expiração por inatividade."""
from datetime import datetime, timedelta

from servicos import permissoes
from servicos.erros import AcessoNegado, SessaoExpirada

INATIVIDADE = timedelta(minutes=30)


class Sessao:
    def __init__(self, usuario, relogio=datetime.now):
        self.id_usuario = usuario["id_usuario"]
        self.nome = usuario["nome"]
        self.email = usuario["email"]
        self.perfil = usuario["perfil"]
        self.id_profissional = usuario.get("id_profissional")
        self._relogio = relogio
        self.ultimo_uso = relogio()
        self.encerrada = False

    def ativa(self):
        return (not self.encerrada
                and self._relogio() - self.ultimo_uso < INATIVIDADE)

    def tocar(self):
        """Renova a sessão ou levanta SessaoExpirada."""
        if not self.ativa():
            self.encerrada = True
            raise SessaoExpirada()
        self.ultimo_uso = self._relogio()

    def registrar_atividade(self):
        if self.ativa():
            self.ultimo_uso = self._relogio()

    def encerrar(self):
        self.encerrada = True

    def pode_ver(self, modulo):
        return permissoes.pode_ver(self.perfil, modulo)

    def pode_editar(self, modulo):
        return permissoes.pode_editar(self.perfil, modulo)

    def exigir(self, modulo, editar=False):
        """Renova a sessão e confere se o perfil acessa o módulo."""
        self.tocar()
        ok = self.pode_editar(modulo) if editar else self.pode_ver(modulo)
        if not ok:
            raise AcessoNegado()
