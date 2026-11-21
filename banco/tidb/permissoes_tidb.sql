-- ============================================================
-- ZENITH - PERMISSOES NO TIDB CLOUD (gerado por gerar_sql_completo.py)
-- Execute com o usuario administrador, DEPOIS de zenith_completo_tidb.sql.
-- No TiDB Cloud Starter todo usuario leva o prefixo do cluster, mostrado em
-- Connect no console (ex.: 3xYz.root). Troque PREFIXO por ele e
-- TROQUE_ESTA_SENHA pela senha de cada usuario. NUNCA grave senhas reais
-- neste arquivo nem no Git: a senha do zenith_app fica so no arquivo .env.
-- ============================================================

-- ----- zenith_app: usuario do aplicativo -----
-- Consulta, inclui e altera; NAO apaga cadastros e NAO altera estrutura.
CREATE USER IF NOT EXISTS 'PREFIXO.zenith_app'@'%' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
GRANT SELECT, INSERT, UPDATE ON zenith.* TO 'PREFIXO.zenith_app'@'%';
-- DELETE so nas duas tabelas de DETALHE (itens do atendimento e insumos
-- padrao do procedimento), necessario para editar essas listas no app.
GRANT DELETE ON zenith.atendimento_procedimento TO 'PREFIXO.zenith_app'@'%';
GRANT DELETE ON zenith.procedimento_insumo TO 'PREFIXO.zenith_app'@'%';

-- ----- zenith_bi: usuario do Power BI (somente leitura) -----
CREATE USER IF NOT EXISTS 'PREFIXO.zenith_bi'@'%' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
GRANT SELECT ON zenith.* TO 'PREFIXO.zenith_bi'@'%';

-- ----- banco de testes (so se zenith_teste_tidb.sql foi executado) -----
-- Os testes automaticos gravam e apagam o que criam, por isso o DELETE.
GRANT SELECT, INSERT, UPDATE, DELETE ON zenith_teste.* TO 'PREFIXO.zenith_app'@'%';

FLUSH PRIVILEGES;

-- Conferencia:
-- SHOW GRANTS FOR 'PREFIXO.zenith_app'@'%';
-- SHOW GRANTS FOR 'PREFIXO.zenith_bi'@'%';
