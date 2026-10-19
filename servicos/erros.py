"""Exceções da camada de serviços. Todas trazem mensagem clara em português,
pronta para mostrar ao usuário (nunca texto técnico)."""

MSG_BANCO = ("Não foi possível acessar o banco de dados. "
             "Verifique se o MySQL está ligado e tente novamente.")


class ErroNegocio(Exception):
    """Base: .mensagem é o texto para o usuário."""

    def __init__(self, mensagem):
        self.mensagem = mensagem
        super().__init__(mensagem)


class DadosInvalidos(ErroNegocio):
    """Dados reprovados. .erros = {campo: mensagem}; campo None = erro geral."""

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
    """Mensagem padrão de campo obrigatório."""
    return f"O campo {rotulo} é obrigatório."
