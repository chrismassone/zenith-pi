-- Rodar no Workbench: selecione o bloco inteiro e use Ctrl+Shift+Enter.
-- Para outro schema, troque a linha USE.
USE zenith;

-- ===== 1. CONTAGEM DE LINHAS (Figura 6) =====
SELECT 'unidade' AS tabela, COUNT(*) AS linhas FROM unidade
UNION ALL SELECT 'profissional', COUNT(*) FROM profissional
UNION ALL SELECT 'usuario', COUNT(*) FROM usuario
UNION ALL SELECT 'paciente', COUNT(*) FROM paciente
UNION ALL SELECT 'anamnese', COUNT(*) FROM anamnese
UNION ALL SELECT 'procedimento', COUNT(*) FROM procedimento
UNION ALL SELECT 'fornecedor', COUNT(*) FROM fornecedor
UNION ALL SELECT 'insumo', COUNT(*) FROM insumo
UNION ALL SELECT 'procedimento_insumo', COUNT(*) FROM procedimento_insumo
UNION ALL SELECT 'atendimento', COUNT(*) FROM atendimento
UNION ALL SELECT 'atendimento_procedimento', COUNT(*) FROM atendimento_procedimento
UNION ALL SELECT 'compra', COUNT(*) FROM compra
UNION ALL SELECT 'consumo', COUNT(*) FROM consumo
UNION ALL SELECT 'lancamento', COUNT(*) FROM lancamento;

-- ===== 2. ESTRUTURA (esperado: 14 BASE TABLE e 12 VIEW) =====
SELECT TABLE_TYPE AS tipo, COUNT(*) AS quantidade
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY TABLE_TYPE;

-- ===== 3. ATENDIMENTOS POR MÊS E SITUAÇÃO =====
SELECT DATE_FORMAT(data_hora, '%Y-%m') AS ano_mes, status, COUNT(*) AS atendimentos
FROM atendimento
GROUP BY DATE_FORMAT(data_hora, '%Y-%m'), status
ORDER BY ano_mes, status;

-- ===== 4. FIGURA 7: consulta 01, agenda dos próximos 30 dias (Mooca) =====
SET @unidade = 1;
SET @inicio  = CURDATE();
SET @fim     = CURDATE() + INTERVAL 30 DAY;
SELECT a.id_atendimento, a.data_hora, u.nome_clinica,
       p.nome_completo AS paciente, p.telefone_paciente, a.status,
       GROUP_CONCAT(pr.nome_procedimento ORDER BY pr.nome_procedimento SEPARATOR ', ') AS procedimentos
FROM atendimento a
JOIN unidade u  ON u.id_unidade  = a.id_unidade
JOIN paciente p ON p.id_paciente = a.id_paciente
LEFT JOIN atendimento_procedimento ap ON ap.id_atendimento = a.id_atendimento
LEFT JOIN procedimento pr             ON pr.id_procedimento = ap.id_procedimento
WHERE a.id_unidade = @unidade
  AND a.data_hora >= @inicio
  AND a.data_hora <  @fim + INTERVAL 1 DAY
GROUP BY a.id_atendimento, a.data_hora, u.nome_clinica, p.nome_completo,
         p.telefone_paciente, a.status
ORDER BY a.data_hora
LIMIT 12;

-- ===== 5. FIGURA 8: consulta 02, retornos pendentes =====
SELECT r.nome_completo, r.telefone_paciente, r.nome_procedimento,
       r.ultima_data, r.data_retorno_prevista,
       DATEDIFF(CURDATE(), r.data_retorno_prevista) AS dias_em_atraso
FROM vw_dash_retorno r
WHERE r.vencido AND NOT r.retornou
ORDER BY dias_em_atraso DESC
LIMIT 10;

-- ===== 6. FIGURA 9: consulta 03, margem por unidade e mês (últimos 4 meses) =====
SELECT ano_mes, nome_clinica, faturamento, dias_com_atendimento,
       custo_locacao, despesas, margem
FROM vw_dash_unidade
WHERE ano_mes >= DATE_FORMAT(CURDATE() - INTERVAL 3 MONTH, '%Y-%m')
ORDER BY ano_mes, nome_clinica;

-- ===== 7. FIGURA 10: consulta 04, faturamento por procedimento =====
SELECT nome_procedimento,
       SUM(quantidade_realizada) AS vezes_realizado,
       SUM(faturamento)          AS faturamento
FROM vw_dash_procedimento
WHERE ano_mes BETWEEN '2026-07' AND '2026-09'
GROUP BY id_procedimento, nome_procedimento
ORDER BY faturamento DESC;

-- ===== 8. FIGURA 11: consulta 07, taxa de comparecimento =====
SELECT u.nome_clinica,
       SUM(c.realizados) AS realizados,
       SUM(c.faltas)     AS faltas,
       ROUND(100 * SUM(c.realizados) / NULLIF(SUM(c.realizados) + SUM(c.faltas), 0), 1)
                         AS taxa_comparecimento_pct
FROM vw_dash_comparecimento c
JOIN unidade u ON u.id_unidade = c.id_unidade
GROUP BY u.id_unidade, u.nome_clinica
ORDER BY taxa_comparecimento_pct DESC;

-- ===== 9. FIGURA 12: consulta 08, estoque atual =====
SELECT nome_insumo, marca, unidade_medida, total_comprado, total_consumido,
       saldo, estoque_minimo,
       CASE WHEN abaixo_minimo THEN 'ABAIXO DO MÍNIMO' ELSE 'OK' END AS situacao
FROM vw_estoque_atual
WHERE ativo = TRUE
ORDER BY abaixo_minimo DESC, nome_insumo
LIMIT 12;

-- ===== 10. CHECAGEM DO RETORNO =====
SELECT COUNT(*)                          AS combinacoes_paciente_procedimento,
       SUM(vencido)                      AS vencidos,
       SUM(retornou)                     AS retornaram,
       SUM(vencido AND NOT retornou)     AS pendentes_vencidos,
       SUM(NOT retornou)                 AS nao_retornaram_total,
       ROUND(100 * SUM(vencido AND retornou) / NULLIF(SUM(vencido), 0), 1) AS taxa_retorno_pct,
       MAX(data_retorno_prevista)        AS maior_data_prevista
FROM vw_dash_retorno;

-- ===== 11. INTEGRIDADE (todas devem retornar 0) =====
SELECT 'agendado em fim de semana' AS checagem, COUNT(*) AS ocorrencias
  FROM atendimento WHERE status = 'Agendado' AND DAYOFWEEK(data_hora) IN (1, 7)
UNION ALL SELECT 'agendado no feriado de 02/11/2026', COUNT(*)
  FROM atendimento WHERE status = 'Agendado' AND DATE(data_hora) = '2026-11-02'
UNION ALL SELECT 'realizado sem forma de pagamento', COUNT(*)
  FROM atendimento WHERE status = 'Realizado' AND forma_pagamento IS NULL
UNION ALL SELECT 'realizado sem procedimento', COUNT(*)
  FROM vw_valor_atendimento WHERE status = 'Realizado' AND qtd_itens = 0
UNION ALL SELECT 'insumo com saldo negativo', COUNT(*)
  FROM vw_estoque_atual WHERE saldo < 0
UNION ALL SELECT 'agendado com consumo registrado', COUNT(*)
  FROM consumo c JOIN atendimento a ON a.id_atendimento = c.id_atendimento
  WHERE a.status = 'Agendado';
