-- ============================================================
-- ZENITH - verificacao dos requisitos da entrega
-- "BD com pelo menos 5 tabelas e tabela principal com pelo menos 100 linhas"
-- Rodar no MySQL Workbench depois de zenith_completo.sql (somente leitura).
-- ============================================================
USE zenith;

-- 1. Quantidade de tabelas (requisito: pelo menos 5). Esperado: 14.
SELECT COUNT(*) AS tabelas
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'zenith' AND TABLE_TYPE = 'BASE TABLE';

-- 2. Linhas por tabela (requisito: tabela principal com pelo menos 100).
--    Tabelas principais: paciente, atendimento, atendimento_procedimento,
--    compra e consumo.
SELECT 'paciente' AS tabela, COUNT(*) AS linhas, 'principal' AS papel FROM paciente
UNION ALL SELECT 'atendimento', COUNT(*), 'principal' FROM atendimento
UNION ALL SELECT 'atendimento_procedimento', COUNT(*), 'principal' FROM atendimento_procedimento
UNION ALL SELECT 'compra', COUNT(*), 'principal' FROM compra
UNION ALL SELECT 'consumo', COUNT(*), 'principal' FROM consumo
UNION ALL SELECT 'anamnese', COUNT(*), 'apoio' FROM anamnese
UNION ALL SELECT 'lancamento', COUNT(*), 'apoio' FROM lancamento
UNION ALL SELECT 'procedimento_insumo', COUNT(*), 'apoio' FROM procedimento_insumo
UNION ALL SELECT 'insumo', COUNT(*), 'apoio' FROM insumo
UNION ALL SELECT 'procedimento', COUNT(*), 'apoio' FROM procedimento
UNION ALL SELECT 'fornecedor', COUNT(*), 'apoio' FROM fornecedor
UNION ALL SELECT 'unidade', COUNT(*), 'apoio' FROM unidade
UNION ALL SELECT 'profissional', COUNT(*), 'apoio' FROM profissional
UNION ALL SELECT 'usuario', COUNT(*), 'apoio' FROM usuario;

-- 3. Resumo: SIM quando o requisito foi atendido.
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'zenith' AND TABLE_TYPE = 'BASE TABLE') AS tabelas,
  CASE WHEN (SELECT COUNT(*) FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = 'zenith' AND TABLE_TYPE = 'BASE TABLE') >= 5
       THEN 'SIM' ELSE 'NAO' END AS pelo_menos_5_tabelas,
  (SELECT COUNT(*) FROM paciente) AS linhas_paciente,
  (SELECT COUNT(*) FROM atendimento) AS linhas_atendimento,
  CASE WHEN (SELECT COUNT(*) FROM paciente) >= 100
        AND (SELECT COUNT(*) FROM atendimento) >= 100
       THEN 'SIM' ELSE 'NAO' END AS tabela_principal_100_linhas;
