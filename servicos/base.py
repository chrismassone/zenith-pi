"""Tradução de erros do banco para erros de negócio, comum aos serviços."""
from contextlib import contextmanager

from repositorios.base import RegistroDuplicado, RegraDoBanco
from servicos.erros import BancoIndisponivel, DadosInvalidos, ErroNegocio, SaldoInsuficiente


@contextmanager
def banco(duplicados=None):
    """Envolve chamadas a repositórios:

        with banco({"uq_paciente_cpf": ("cpf", "Já existe um paciente com este CPF.")}):
            repo.inserir(...)

    'duplicados' associa o nome da restrição UNIQUE ao campo e à mensagem.
    """
    try:
        yield
    except RegistroDuplicado as erro:
        campo, msg = (duplicados or {}).get(erro.chave, (None, "Registro duplicado."))
        raise DadosInvalidos({campo: msg}) from erro
    except RegraDoBanco as erro:
        if "Saldo insuficiente" in str(erro) or "saldo" in str(erro).lower():
            raise SaldoInsuficiente(
                "Saldo insuficiente em estoque para esta operação.") from erro
        raise ErroNegocio("O banco de dados recusou a operação: os dados não "
                          "atendem às regras do sistema.") from erro
    except (ConnectionError, RuntimeError) as erro:
        raise BancoIndisponivel() from erro
