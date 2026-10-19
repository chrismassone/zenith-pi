"""Aponta os testes que gravam dados para o banco separado zenith_teste.

Uso nos testes (ANTES de importar qualquer módulo do projeto que use o banco):
    import banco_teste
    banco_teste.usar()

Para carregar a população fictícia no banco de teste (uma vez, com ele vazio):
    python banco_teste.py carregar
"""
import os
import sys

NOME = "zenith_teste"


def usar():
    """Troca o banco para zenith_teste e confirma que a troca funcionou.
    Encerra o teste se não estiver no banco de teste, para nunca gravar
    dados de teste no banco principal."""
    os.environ["DB_NAME"] = NOME   # o .env não sobrescreve variável já definida
    from database.conexao import conectar
    try:
        conn = conectar()
    except ConnectionError:
        sys.exit("Banco de teste indisponível. Execute banco/teste/zenith_banco_teste.sql como root "
                 "(gerado por gerar_banco_teste.py) e tente de novo.")
    cur = conn.cursor()
    cur.execute("SELECT DATABASE()")
    atual = cur.fetchone()[0]
    conn.close()
    if atual != NOME:
        sys.exit(f"Teste interrompido: conectado a '{atual}', esperado '{NOME}'.")


def carregar():
    usar()
    from pathlib import Path
    from database.conexao import conectar
    conn = conectar()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM unidade")
    if cur.fetchone()[0]:
        sys.exit("O banco de teste já tem dados; nada foi carregado.")
    arquivo = Path(__file__).resolve().parent / "banco" / "historico" / "zenith_populacao.sql"
    linhas = [l for l in arquivo.read_text(encoding="utf-8").splitlines()
              if l.startswith("INSERT")]
    try:
        for linha in linhas:
            cur.execute(linha)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
    print(f"{len(linhas)} linhas carregadas em {NOME}.")


# ordem de exclusão que respeita as chaves estrangeiras (filhas primeiro)
ORDEM_LIMPEZA = ("consumo", "compra", "atendimento_procedimento", "atendimento",
                 "procedimento_insumo", "anamnese", "lancamento", "usuario", "paciente",
                 "insumo", "fornecedor", "procedimento", "profissional", "unidade")


def recarregar():
    """Apaga TODOS os dados do zenith_teste e carrega zenith_populacao.sql de
    novo, numa transação. Só dados (o zenith_app não tem DDL); a estrutura
    vem de zenith_banco_teste.sql, executado como root."""
    usar()
    from pathlib import Path
    from database.conexao import conectar
    arquivo = Path(__file__).resolve().parent / "banco" / "historico" / "zenith_populacao.sql"
    linhas = [l for l in arquivo.read_text(encoding="utf-8").splitlines()
              if l.startswith("INSERT")]
    conn = conectar()
    try:
        cur = conn.cursor()
        cur.execute("SELECT DATABASE()")
        assert cur.fetchone()[0] == NOME, "recarga permitida só no banco de teste"
        for tabela in ORDEM_LIMPEZA:
            cur.execute(f"DELETE FROM {tabela}")
        for linha in linhas:
            cur.execute(linha)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
    print(f"{NOME} recarregado: {len(linhas)} linhas.")


if __name__ == "__main__" and sys.argv[1:] == ["carregar"]:
    carregar()
elif __name__ == "__main__" and sys.argv[1:] == ["recarregar"]:
    recarregar()
