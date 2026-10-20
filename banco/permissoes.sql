-- ============================================================
-- ZENITH - PERMISSOES DO MYSQL (gerado por gerar_sql_completo.py)
-- Execute como root, DEPOIS de zenith_completo.sql.
-- Troque TROQUE_ESTA_SENHA pela senha de cada usuario. NUNCA grave senhas reais
-- neste arquivo nem no Git: a senha do zenith_app fica so no arquivo .env.
-- ============================================================

-- ----- zenith_app: usuario do aplicativo -----
-- Consulta, inclui e altera; NAO apaga cadastros e NAO altera estrutura.
-- Se o usuario ja existir, o CREATE abaixo e ignorado.
CREATE USER IF NOT EXISTS 'zenith_app'@'localhost' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
GRANT SELECT, INSERT, UPDATE ON zenith.* TO 'zenith_app'@'localhost';
-- DELETE so nas duas tabelas de DETALHE (itens do atendimento e insumos
-- padrao do procedimento), necessario para editar essas listas no app.
GRANT DELETE ON zenith.atendimento_procedimento TO 'zenith_app'@'localhost';
GRANT DELETE ON zenith.procedimento_insumo TO 'zenith_app'@'localhost';

-- ----- zenith_bi: usuario do Power BI (somente leitura) -----
CREATE USER IF NOT EXISTS 'zenith_bi'@'localhost' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
GRANT SELECT ON zenith.* TO 'zenith_bi'@'localhost';

FLUSH PRIVILEGES;

-- Conferencia:
-- SHOW GRANTS FOR 'zenith_app'@'localhost';
-- SHOW GRANTS FOR 'zenith_bi'@'localhost';
