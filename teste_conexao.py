from database.conexao import conectar

conn = conectar()
cursor = conn.cursor()

cursor.execute("SELECT nome_clinica FROM unidade")
for (nome,) in cursor.fetchall():
    print(nome)

cursor.close()
conn.close()
