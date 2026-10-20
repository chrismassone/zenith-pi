from repositorios.base import consultar, executar

COLUNAS = ("id_usuario, nome, email, senha_hash, perfil, id_profissional, ativo, "
           "tentativas_falhas, bloqueado_ate, ultimo_acesso")


def buscar_por_email(email):
    return consultar(f"SELECT {COLUNAS} FROM usuario WHERE email = %s", (email,), um=True)


def buscar_por_id(id_usuario):
    return consultar(f"SELECT {COLUNAS} FROM usuario WHERE id_usuario = %s",
                     (id_usuario,), um=True)


def inserir(nome, email, senha_hash, perfil, id_profissional=None):
    novo_id, _ = executar(
        """INSERT INTO usuario (nome, email, senha_hash, perfil, id_profissional)
           VALUES (%s, %s, %s, %s, %s)""",
        (nome, email, senha_hash, perfil, id_profissional))
    return novo_id


def registrar_falha(id_usuario, tentativas, bloqueado_ate):
    executar("UPDATE usuario SET tentativas_falhas = %s, bloqueado_ate = %s "
             "WHERE id_usuario = %s", (tentativas, bloqueado_ate, id_usuario))


def registrar_sucesso(id_usuario, quando):
    executar("UPDATE usuario SET tentativas_falhas = 0, bloqueado_ate = NULL, "
             "ultimo_acesso = %s WHERE id_usuario = %s", (quando, id_usuario))
