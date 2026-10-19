"""Testes do login, bloqueio, sessão e perfis. Não usam o banco: o
repositório de usuários é substituído por um falso, em memória."""
from datetime import datetime, timedelta

from servicos import autenticacao, permissoes
from servicos.erros import AcessoNegado, DadosInvalidos, LoginRecusado, SessaoExpirada

# senha fictícia, só deste teste
SENHA = "senha-ficticia-de-teste"


class RepoFalso:
    def __init__(self):
        self.usuarios = {}

    def buscar_por_email(self, email):
        u = self.usuarios.get(email)
        return dict(u) if u else None

    def inserir(self, nome, email, senha_hash, perfil, id_profissional=None):
        if email in self.usuarios:
            from repositorios.base import RegistroDuplicado
            raise RegistroDuplicado("uq_usuario_email")
        novo = dict(id_usuario=len(self.usuarios) + 1, nome=nome, email=email,
                    senha_hash=senha_hash, perfil=perfil, id_profissional=id_profissional,
                    ativo=True, tentativas_falhas=0, bloqueado_ate=None, ultimo_acesso=None)
        self.usuarios[email] = novo
        return novo["id_usuario"]

    def _por_id(self, id_usuario):
        return next(u for u in self.usuarios.values() if u["id_usuario"] == id_usuario)

    def registrar_falha(self, id_usuario, tentativas, bloqueado_ate):
        u = self._por_id(id_usuario)
        u["tentativas_falhas"], u["bloqueado_ate"] = tentativas, bloqueado_ate

    def registrar_sucesso(self, id_usuario, quando):
        u = self._por_id(id_usuario)
        u["tentativas_falhas"], u["bloqueado_ate"], u["ultimo_acesso"] = 0, None, quando


class Relogio:
    def __init__(self):
        self.agora = datetime(2026, 10, 16, 9, 0)

    def __call__(self):
        return self.agora

    def avancar(self, **kw):
        self.agora += timedelta(**kw)


def recusa(func):
    try:
        func()
        return None
    except LoginRecusado as e:
        return e.mensagem


casos = []


def caso(nome, obtido, esperado):
    casos.append((nome, obtido, esperado))


repo, relogio = RepoFalso(), Relogio()
autenticacao.criar_usuario("Gerente Ficticia", "Gerente@Exemplo.invalid", "Gerente",
                           SENHA, SENHA, repo=repo)
u = repo.usuarios["gerente@exemplo.invalid"]
caso("E-mail guardado em minúsculas", "gerente@exemplo.invalid" in repo.usuarios, True)
caso("Senha guardada só como hash bcrypt", (u["senha_hash"].startswith("$2"),
                                            SENHA in u["senha_hash"]), (True, False))

entrar = lambda email, senha: autenticacao.entrar(email, senha, repo=repo, relogio=relogio)
sessao = entrar(" GERENTE@exemplo.invalid ", SENHA)
caso("Login correto devolve sessão de Gerente", sessao.perfil, "Gerente")
caso("Login registra último acesso", u["ultimo_acesso"], relogio.agora)

caso("Senha errada: mensagem genérica",
     recusa(lambda: entrar("gerente@exemplo.invalid", "errada")), autenticacao.MSG_GENERICA)
caso("E-mail inexistente: mesma mensagem genérica",
     recusa(lambda: entrar("ninguem@exemplo.invalid", SENHA)), autenticacao.MSG_GENERICA)
caso("Campos vazios: mensagem genérica", recusa(lambda: entrar("", "")),
     autenticacao.MSG_GENERICA)

for _ in range(3):
    recusa(lambda: entrar("gerente@exemplo.invalid", "errada"))
caso("4 erros seguidos ainda não bloqueiam", u["bloqueado_ate"], None)
msg5 = recusa(lambda: entrar("gerente@exemplo.invalid", "errada"))
caso("5º erro bloqueia", (msg5, u["bloqueado_ate"] is not None),
     (autenticacao.MSG_BLOQUEIO, True))
caso("Bloqueado: nem a senha certa entra",
     recusa(lambda: entrar("gerente@exemplo.invalid", SENHA)), autenticacao.MSG_BLOQUEIO)
relogio.avancar(minutes=16)
caso("Após o bloqueio, senha certa entra",
     entrar("gerente@exemplo.invalid", SENHA).perfil, "Gerente")
caso("Sucesso zera as tentativas", u["tentativas_falhas"], 0)

u["ativo"] = False
caso("Usuário inativo: mensagem genérica",
     recusa(lambda: entrar("gerente@exemplo.invalid", SENHA)), autenticacao.MSG_GENERICA)
u["ativo"] = True

# --- sessão e expiração ---
s = entrar("gerente@exemplo.invalid", SENHA)
relogio.avancar(minutes=29)
s.tocar()
caso("Atividade aos 29 min renova a sessão", s.ativa(), True)
relogio.avancar(minutes=30)
try:
    s.tocar()
    expirou = False
except SessaoExpirada:
    expirou = True
caso("30 min sem atividade: sessão expira", (expirou, s.ativa()), (True, False))
s2 = entrar("gerente@exemplo.invalid", SENHA)
s2.encerrar()
caso("Sair encerra a sessão", s2.ativa(), False)

# --- validação de novo usuário ---
def erros_criar(*args):
    try:
        autenticacao.criar_usuario(*args, repo=repo)
        return {}
    except DadosInvalidos as e:
        return e.erros

caso("Senha curta recusada", list(erros_criar("X", "x@exemplo.invalid", "Gerente",
                                             "curta", "curta")), ["senha"])
caso("Confirmação diferente recusada",
     erros_criar("X", "x@exemplo.invalid", "Gerente", SENHA, SENHA + "!").get("senha"),
     "A confirmação não confere com a senha.")
caso("Perfil inexistente recusado",
     list(erros_criar("X", "x@exemplo.invalid", "Dono", SENHA, SENHA)), ["perfil"])
caso("Nome vazio: mensagem padrão",
     erros_criar("", "x@exemplo.invalid", "Gerente", SENHA, SENHA).get("nome"),
     "O campo Nome é obrigatório.")
caso("E-mail duplicado recusado",
     erros_criar("Outra", "gerente@exemplo.invalid", "Atendente", SENHA, SENHA).get("email"),
     "Já existe um usuário com este e-mail.")

# --- perfis ---
P = permissoes
caso("Gerente vê tudo", P.modulos_visiveis("Gerente"), list(P.MODULOS))
caso("Atendente: menu", P.modulos_visiveis("Atendente"),
     ["inicio", "pacientes", "atendimentos", "procedimentos", "unidades", "insumos"])
caso("Atendente: Unidades só leitura",
     (P.pode_ver("Atendente", "unidades"), P.pode_editar("Atendente", "unidades")),
     (True, False))
caso("Atendente sem Financeiro e Dashboard",
     (P.pode_ver("Atendente", "financeiro"), P.pode_ver("Atendente", "dashboard")),
     (False, False))
caso("Profissional: menu", P.modulos_visiveis("Profissional"),
     ["inicio", "pacientes", "anamnese", "atendimentos"])
autenticacao.criar_usuario("Atendente Ficticia", "atendente@exemplo.invalid", "Atendente",
                           SENHA, SENHA, repo=repo)
sa = entrar("atendente@exemplo.invalid", SENHA)
try:
    sa.exigir("financeiro")
    negado = False
except AcessoNegado:
    negado = True
caso("Serviço recusa Financeiro para Atendente", negado, True)
try:
    sa.exigir("unidades", editar=True)
    negado = False
except AcessoNegado:
    negado = True
caso("Serviço recusa editar Unidades para Atendente", negado, True)

falhas = 0
for nome, obtido, esperado in casos:
    ok = obtido == esperado
    falhas += not ok
    print(("OK   " if ok else "FALHA"), nome, "" if ok else f"(obtido {obtido!r})")
print(f"\n{len(casos) - falhas}/{len(casos)} testes passaram")
