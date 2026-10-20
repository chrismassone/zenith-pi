"""Exceções com mensagens prontas para o usuário."""

MSG_BANCO = ("Não foi possível acessar o banco de dados. "
             "Verifique se o MySQL está ligado e tente novamente.")


class ErroNegocio(Exception):
    def __init__(self, mensagem):
        self.mensagem = mensagem
        super().__init__(mensagem)


class DadosInvalidos(ErroNegocio):
    """.erros = {campo: mensagem}; campo None é erro geral."""

    def __init__(self, erros):
        self.erros = dict(erros)
        super().__init__(" ".join(self.erros.values()) or "Dados inválidos.")


class AcessoNegado(ErroNegocio):
    def __init__(self, mensagem="Seu perfil não tem acesso a esta função."):
        super().__init__(mensagem)


class SessaoExpirada(ErroNegocio):
    def __init__(self):
        super().__init__("Sua sessão expirou por inatividade. Entre novamente.")


class LoginRecusado(ErroNegocio):
    pass


class SaldoInsuficiente(ErroNegocio):
    pass


class NaoEncontrado(ErroNegocio):
    def __init__(self, mensagem="Registro não encontrado. Ele pode ter sido alterado."):
        super().__init__(mensagem)


class BancoIndisponivel(ErroNegocio):
    def __init__(self):
        super().__init__(MSG_BANCO)


def obrigatorio(rotulo):
    return f"O campo {rotulo} é obrigatório."
