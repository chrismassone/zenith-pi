"""Cria um usuário do sistema. Uso: python criar_usuario.py"""
from getpass import getpass

from servicos import autenticacao, permissoes
from servicos.erros import BancoIndisponivel, DadosInvalidos


def perguntar(texto):
    return input(texto).strip()


def escolher_perfil():
    print("Perfis: 1 = Gerente, 2 = Atendente, 3 = Profissional")
    while True:
        escolha = perguntar("Perfil (1, 2 ou 3): ")
        if escolha in ("1", "2", "3"):
            return permissoes.PERFIS[int(escolha) - 1]
        print("Opção inválida.")


def escolher_profissional():
    from repositorios import profissional
    lista = profissional.listar()
    if not lista:
        print("Nenhuma profissional cadastrada; o usuário ficará sem vínculo.")
        return None
    for p in lista:
        print(f"  {p['id_profissional']} = {p['nome_completo']}")
    validos = {str(p["id_profissional"]) for p in lista}
    while True:
        escolha = perguntar("Número da profissional vinculada a este usuário: ")
        if escolha in validos:
            return int(escolha)
        print("Opção inválida.")


def main():
    print("Criar usuário do Zenith\n")
    nome = perguntar("Nome: ")
    email = perguntar("E-mail: ")
    perfil = escolher_perfil()
    try:
        id_prof = escolher_profissional() if perfil == permissoes.PROFISSIONAL else None
    except (ConnectionError, RuntimeError):
        print(BancoIndisponivel().mensagem)
        return 1
    print(f"A senha deve ter pelo menos {autenticacao.SENHA_MINIMA} caracteres "
          "e não aparece enquanto você digita.")
    senha = getpass("Senha: ")
    confirmacao = getpass("Repita a senha: ")
    try:
        autenticacao.criar_usuario(nome, email, perfil, senha, confirmacao, id_prof)
    except DadosInvalidos as erro:
        print("\nNão foi possível criar o usuário:")
        for mensagem in erro.erros.values():
            print(" -", mensagem)
        return 1
    except BancoIndisponivel as erro:
        print("\n" + erro.mensagem)
        return 1
    finally:
        senha = confirmacao = None
    print(f"\nUsuário criado: {nome} ({email.lower()}), perfil {perfil}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
