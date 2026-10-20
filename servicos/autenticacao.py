"""Login (bcrypt), bloqueio por tentativas e criação de usuários."""
from datetime import datetime, timedelta
import re

import bcrypt

from repositorios.base import RegistroDuplicado
from servicos import permissoes
from servicos.erros import BancoIndisponivel, DadosInvalidos, LoginRecusado, obrigatorio
from servicos.sessao import Sessao

MAX_TENTATIVAS = 5
TEMPO_BLOQUEIO = timedelta(minutes=15)   # suposição, a confirmar
SENHA_MINIMA = 10
MSG_GENERICA = "E-mail ou senha incorretos."
MSG_BLOQUEIO = ("Acesso bloqueado temporariamente por excesso de tentativas. "
                "Tente novamente em alguns minutos.")
# usado quando o e-mail não existe, para a resposta levar o mesmo tempo
_HASH_REFERENCIA = bcrypt.hashpw(b"referencia-sem-uso", bcrypt.gensalt()).decode("ascii")


def _repo():
    from repositorios import usuario
    return usuario


def gerar_hash(senha):
    return bcrypt.hashpw(senha.encode("utf-8"), bcrypt.gensalt()).decode("ascii")


def senha_confere(senha, senha_hash):
    try:
        return bcrypt.checkpw(senha.encode("utf-8"), senha_hash.encode("ascii"))
    except ValueError:      # hash corrompido: trata como senha errada
        return False


def entrar(email, senha, repo=None, relogio=datetime.now):
    """Devolve uma Sessao ou levanta LoginRecusado / BancoIndisponivel."""
    repo = repo or _repo()
    email = (email or "").strip().lower()
    if not email or not senha:
        raise LoginRecusado(MSG_GENERICA)
    try:
        usuario = repo.buscar_por_email(email)
        agora = relogio()
        if usuario is None or not usuario["ativo"]:
            senha_confere(senha, _HASH_REFERENCIA)
            raise LoginRecusado(MSG_GENERICA)
        if usuario["bloqueado_ate"] and usuario["bloqueado_ate"] > agora:
            raise LoginRecusado(MSG_BLOQUEIO)
        if not senha_confere(senha, usuario["senha_hash"]):
            tentativas = usuario["tentativas_falhas"] + 1
            bloqueio = None
            if tentativas >= MAX_TENTATIVAS:
                bloqueio, tentativas = agora + TEMPO_BLOQUEIO, 0
            repo.registrar_falha(usuario["id_usuario"], tentativas, bloqueio)
            raise LoginRecusado(MSG_BLOQUEIO if bloqueio else MSG_GENERICA)
        repo.registrar_sucesso(usuario["id_usuario"], agora)
        return Sessao(usuario, relogio=relogio)
    except (ConnectionError, RuntimeError) as erro:
        raise BancoIndisponivel() from erro


def validar_novo_usuario(nome, email, perfil, senha, confirmacao):
    erros = {}
    nome = (nome or "").strip()
    email = (email or "").strip().lower()
    if not nome:
        erros["nome"] = obrigatorio("Nome")
    elif len(nome) > 100:
        erros["nome"] = "Nome: máximo de 100 caracteres."
    if not email:
        erros["email"] = obrigatorio("E-mail")
    elif len(email) > 100 or not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        erros["email"] = "E-mail inválido."
    if perfil not in permissoes.PERFIS:
        erros["perfil"] = "Perfil inválido. Use Gerente, Atendente ou Profissional."
    if len(senha or "") < SENHA_MINIMA:
        erros["senha"] = f"A senha deve ter pelo menos {SENHA_MINIMA} caracteres."
    elif senha != confirmacao:
        erros["senha"] = "A confirmação não confere com a senha."
    return erros


def criar_usuario(nome, email, perfil, senha, confirmacao, id_profissional=None, repo=None):
    repo = repo or _repo()
    erros = validar_novo_usuario(nome, email, perfil, senha, confirmacao)
    if erros:
        raise DadosInvalidos(erros)
    try:
        return repo.inserir(nome.strip(), email.strip().lower(), gerar_hash(senha), perfil,
                            id_profissional if perfil == permissoes.PROFISSIONAL else None)
    except RegistroDuplicado as erro:
        raise DadosInvalidos({"email": "Já existe um usuário com este e-mail."}) from erro
    except (ConnectionError, RuntimeError) as erro:
        raise BancoIndisponivel() from erro
