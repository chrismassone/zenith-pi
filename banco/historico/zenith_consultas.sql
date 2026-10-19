-- ============================================================
-- ZENITH - consultas de apoio aos requisitos RF03, RF07, RF08 e RF09
-- (agenda, retornos, financeiro, estoque e relatórios gerenciais).
-- A associação exata de cada consulta ao número do requisito deve ser
-- conferida com o documento de requisitos do relatório.
--
-- Executar no Workbench conectado ao banco zenith (ou com
-- `python consultas_executar.py`, que roda todas como zenith_app).
-- Cada consulta começa com uma linha "-- [NN] título".
-- Parâmetros ficam em variáveis (@...) logo acima de cada consulta.
-- ============================================================
USE zenith;

-- [01] Agenda por unidade e período (JOIN de 5 tabelas)
-- Lista os atendimentos de uma unidade num intervalo, com paciente,
-- telefone e procedimentos previstos.
SET @unidade = 1;
SET @inicio  = '2026-10-16';
SET @fim     = '2026-11-15';
SELECT a.id_atendimento,
       a.data_hora,
       u.nome_clinica,
       p.nome_completo                                         AS paciente,
       p.telefone_paciente,
       a.status,
       GROUP_CONCAT(pr.nome_procedimento ORDER BY pr.nome_procedimento SEPARATOR ', ')
                                                               AS procedimentos
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
ORDER BY a.data_hora;

-- [02] Retornos pendentes: prazo de retorno vencido e paciente sem novo
-- atendimento agendado ou realizado (view vw_dash_retorno).
SELECT r.nome_completo,
       r.telefone_paciente,
       r.nome_procedimento,
       r.ultima_data,
       r.data_retorno_prevista,
       DATEDIFF(CURDATE(), r.data_retorno_prevista) AS dias_em_atraso
FROM vw_dash_retorno r
WHERE r.vencido AND NOT r.retornou
ORDER BY dias_em_atraso DESC;

-- [03] Faturamento, custo de locação, despesas e margem por unidade e mês
-- SUPOSIÇÃO: custo de locação = valor_locacao x dias com atendimento
-- Realizado (regra a confirmar com a cliente; ver vw_dash_unidade).
SELECT ano_mes, nome_clinica, faturamento, dias_com_atendimento,
       custo_locacao, despesas, margem
FROM vw_dash_unidade
ORDER BY ano_mes, nome_clinica;

-- [04] Faturamento por procedimento no período (GROUP BY)
SET @inicio = '2026-07-01';
SET @fim    = '2026-09-30';
SELECT nome_procedimento,
       SUM(quantidade_realizada) AS vezes_realizado,
       SUM(faturamento)          AS faturamento
FROM vw_dash_procedimento
WHERE ano_mes BETWEEN DATE_FORMAT(@inicio, '%Y-%m') AND DATE_FORMAT(@fim, '%Y-%m')
GROUP BY id_procedimento, nome_procedimento
ORDER BY faturamento DESC;

-- [05] Ticket médio por unidade (só atendimentos Realizado)
SELECT f.nome_clinica,
       COUNT(*)                      AS atendimentos_realizados,
       SUM(f.valor_total)            AS faturamento,
       ROUND(AVG(f.valor_total), 2)  AS ticket_medio
FROM vw_faturamento f
GROUP BY f.id_unidade, f.nome_clinica
ORDER BY ticket_medio DESC;

-- [06] Pacientes ativos por cidade e bairro, só bairros com 3 ou mais
-- pacientes (GROUP BY com HAVING)
SELECT cidade_paciente AS cidade,
       bairro_paciente AS bairro,
       COUNT(*)        AS pacientes_ativos
FROM paciente
WHERE ativo = TRUE
GROUP BY cidade_paciente, bairro_paciente
HAVING COUNT(*) >= 3
ORDER BY cidade, pacientes_ativos DESC;

-- [07] Taxa de comparecimento por unidade:
-- realizados / (realizados + faltas). Cancelados não entram.
SELECT u.nome_clinica,
       SUM(c.realizados) AS realizados,
       SUM(c.faltas)     AS faltas,
       ROUND(100 * SUM(c.realizados) / NULLIF(SUM(c.realizados) + SUM(c.faltas), 0), 1)
                         AS taxa_comparecimento_pct
FROM vw_dash_comparecimento c
JOIN unidade u ON u.id_unidade = c.id_unidade
GROUP BY u.id_unidade, u.nome_clinica
ORDER BY taxa_comparecimento_pct DESC;

-- [08] Estoque atual de todos os insumos ativos, com alerta de mínimo
SELECT nome_insumo, marca, unidade_medida, total_comprado, total_consumido,
       saldo, estoque_minimo,
       CASE WHEN abaixo_minimo THEN 'ABAIXO DO MÍNIMO' ELSE 'OK' END AS situacao
FROM vw_estoque_atual
WHERE ativo = TRUE
ORDER BY abaixo_minimo DESC, nome_insumo;

-- [09] Alertas de validade: lotes vencidos ou que vencem em até 60 dias
-- (SUPOSIÇÃO: sem controle FIFO por lote; o saldo é o do insumo).
SELECT nome_insumo, lote, data_compra, data_validade, dias_para_vencer,
       CASE WHEN vencido THEN 'VENCIDO' ELSE 'VENCE EM BREVE' END AS situacao,
       saldo_insumo
FROM vw_alerta_validade
ORDER BY data_validade;

-- [10] Custo estimado de insumos por procedimento e margem estimada
-- (quantidade padrão x preço da compra mais recente).
SELECT nome_procedimento, preco_tabela, custo_insumos, margem_estimada,
       ROUND(100 * margem_estimada / NULLIF(preco_tabela, 0), 1) AS margem_pct
FROM vw_custo_procedimento
ORDER BY margem_estimada DESC;

-- [11] Ranking de origem de captação dos pacientes (GROUP BY com HAVING:
-- só origens com pelo menos 5 pacientes)
SELECT origem_captacao,
       COUNT(*)                                            AS pacientes,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM paciente), 1) AS percentual
FROM paciente
GROUP BY origem_captacao
HAVING COUNT(*) >= 5
ORDER BY pacientes DESC;

-- [12] Novos pacientes por mês (pela data de cadastro)
SELECT DATE_FORMAT(criado_em, '%Y-%m') AS ano_mes,
       COUNT(*)                        AS novos_pacientes
FROM paciente
GROUP BY DATE_FORMAT(criado_em, '%Y-%m')
ORDER BY ano_mes;

-- [13] Histórico de atendimentos de um paciente (JOIN de 4 tabelas)
SET @paciente = 1;
SELECT a.data_hora,
       u.nome_clinica,
       a.status,
       pr.nome_procedimento,
       ap.regiao_aplicada,
       ap.quantidade_aplicada,
       ap.valor_cobrado
FROM atendimento a
JOIN unidade u                   ON u.id_unidade      = a.id_unidade
JOIN atendimento_procedimento ap ON ap.id_atendimento = a.id_atendimento
JOIN procedimento pr             ON pr.id_procedimento = ap.id_procedimento
WHERE a.id_paciente = @paciente
ORDER BY a.data_hora DESC;

-- [14] Consumo real x quantidade padrão por procedimento e insumo
-- (JOIN de 5 tabelas). Responde "quanto cada procedimento consome de
-- insumo": o padrão sugerido e a média realmente usada.
SELECT pr.nome_procedimento,
       i.nome_insumo,
       i.unidade_medida,
       pi.quantidade_padrao,
       ROUND(AVG(c.quantidade), 2) AS media_consumida,
       COUNT(*)                    AS registros
FROM consumo c
JOIN atendimento_procedimento ap ON ap.id_atendimento = c.id_atendimento
JOIN procedimento_insumo pi      ON pi.id_procedimento = ap.id_procedimento
                                AND pi.id_insumo      = c.id_insumo
JOIN procedimento pr             ON pr.id_procedimento = ap.id_procedimento
JOIN insumo i                    ON i.id_insumo       = c.id_insumo
GROUP BY pr.nome_procedimento, i.nome_insumo, i.unidade_medida, pi.quantidade_padrao
ORDER BY pr.nome_procedimento, i.nome_insumo;

-- [15] Compras por fornecedor e insumo (JOIN de 3 tabelas): mostra que o
-- mesmo insumo é comprado de mais de um fornecedor (relação N:M).
SELECT i.nome_insumo,
       f.razao_social,
       COUNT(*)                         AS compras,
       SUM(co.quantidade)               AS quantidade_total,
       ROUND(AVG(co.preco_unitario), 2) AS preco_medio
FROM compra co
JOIN insumo i     ON i.id_insumo     = co.id_insumo
JOIN fornecedor f ON f.id_fornecedor = co.id_fornecedor
GROUP BY i.nome_insumo, f.razao_social
ORDER BY i.nome_insumo, compras DESC;

-- [16] Pacientes ativos sem nenhum atendimento realizado nos últimos 180 dias
-- (subconsulta com NOT EXISTS): lista para ação de reativação.
SELECT p.nome_completo, p.telefone_paciente, p.origem_captacao
FROM paciente p
WHERE p.ativo = TRUE
  AND NOT EXISTS (SELECT 1
                    FROM atendimento a
                   WHERE a.id_paciente = p.id_paciente
                     AND a.status = 'Realizado'
                     AND a.data_hora >= CURDATE() - INTERVAL 180 DAY)
ORDER BY p.nome_completo;

-- [17] Procedimentos com faturamento acima da média dos procedimentos
-- (subconsulta na cláusula HAVING)
SELECT nome_procedimento, SUM(faturamento) AS faturamento
FROM vw_dash_procedimento
GROUP BY id_procedimento, nome_procedimento
HAVING SUM(faturamento) > (SELECT AVG(total)
                             FROM (SELECT SUM(faturamento) AS total
                                     FROM vw_dash_procedimento
                                    GROUP BY id_procedimento) t)
ORDER BY faturamento DESC;

-- [18] Insumos cujo preço da última compra ficou acima do preço médio
-- histórico (subconsulta correlacionada)
SELECT i.nome_insumo,
       pa.preco_unitario                         AS preco_atual,
       (SELECT ROUND(AVG(co.preco_unitario), 2)
          FROM compra co WHERE co.id_insumo = i.id_insumo) AS preco_medio
FROM insumo i
JOIN vw_preco_insumo_atual pa ON pa.id_insumo = i.id_insumo
WHERE pa.preco_unitario > (SELECT AVG(co.preco_unitario)
                             FROM compra co WHERE co.id_insumo = i.id_insumo)
ORDER BY i.nome_insumo;

-- [19] Faturamento por forma de pagamento (GROUP BY com HAVING:
-- só formas com faturamento acima de R$ 10.000)
SELECT forma_pagamento,
       COUNT(*)         AS atendimentos,
       SUM(valor_total) AS faturamento
FROM vw_faturamento
GROUP BY forma_pagamento
HAVING SUM(valor_total) > 10000
ORDER BY faturamento DESC;

-- [20] Faturamento mensal total (base do gráfico de linha do dashboard)
SELECT ano_mes, SUM(faturamento) AS faturamento, SUM(realizados) AS realizados
FROM vw_dash_kpis_mensal
GROUP BY ano_mes
ORDER BY ano_mes;
