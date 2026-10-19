# Resultados de zenith_consultas.sql

Banco: `zenith_teste`. Executado em 17/10/2026 16:21 como zenith_app.
Valores exatamente como o MySQL devolveu (até 10 linhas por consulta).

## [01] Agenda por unidade e período (JOIN de 5 tabelas)

Total de linhas: **22**

| id_atendimento | data_hora | nome_clinica | paciente | telefone_paciente | status | procedimentos |
|---|---|---|---|---|---|---|
| 251 | 2026-10-19 09:00:00 | Unidade Mooca | Mateus Cardoso Rezende | 11915901082 | Agendado | Toxina botulínica |
| 252 | 2026-10-19 09:30:00 | Unidade Mooca | Helena Ramos Pacheco | 11921712768 | Agendado | Toxina botulínica |
| 253 | 2026-10-19 14:00:00 | Unidade Mooca | Tatiana Esteves Macedo | 11965535681 | Agendado | Preenchimento facial |
| 262 | 2026-10-20 11:00:00 | Unidade Mooca | Thiago Antunes Teixeira | 11993113625 | Agendado | Tratamento de olheiras |
| 265 | 2026-10-20 13:00:00 | Unidade Mooca | Diego Valente Lacerda | 11999993218 | Agendado | Tratamento de olheiras |
| 270 | 2026-10-21 14:00:00 | Unidade Mooca | Yasmin Faria Brandão | 11902410060 | Agendado | Preenchimento facial |
| 273 | 2026-10-22 09:00:00 | Unidade Mooca | Fernanda Ramos Guimarães | 11941050014 | Agendado | Tratamento de olheiras |
| 274 | 2026-10-22 09:30:00 | Unidade Mooca | Débora Fontes Cardoso | 11994614334 | Agendado | Tratamento de olheiras |
| 258 | 2026-10-23 10:00:00 | Unidade Mooca | Bruno Queiroz Tavares | 11955845908 | Agendado | Tratamento de olheiras |
| 259 | 2026-10-23 14:00:00 | Unidade Mooca | Carlos Leal Xavier | 11972066384 | Agendado | Preenchimento labial |

## [02] Retornos pendentes: prazo de retorno vencido e paciente sem novo

Total de linhas: **13**

| nome_completo | telefone_paciente | nome_procedimento | ultima_data | data_retorno_prevista | dias_em_atraso |
|---|---|---|---|---|---|
| Natália Antunes Xavier | 11972888797 | Bioestimulador | 2025-11-17 | 2026-05-16 | 154 |
| Raquel Faria Xavier | 11960890501 | Skinbooster | 2026-01-21 | 2026-05-21 | 149 |
| Rafael Gomes Lacerda | 11967985712 | Bioestimulador | 2025-11-27 | 2026-05-26 | 144 |
| Elisa Macedo Sampaio | 11983957614 | Skinbooster | 2026-01-26 | 2026-05-26 | 144 |
| Mateus Macedo Teixeira | 11982477704 | Toxina botulínica | 2026-01-01 | 2026-05-31 | 139 |
| Mariana Xavier Siqueira | 11903729848 | Toxina botulínica | 2026-01-19 | 2026-06-18 | 121 |
| Juliana Ramos Sampaio | 11964694866 | Toxina botulínica | 2026-01-27 | 2026-06-26 | 113 |
| Fernanda Dias Peixoto | 11957042310 | Toxina botulínica | 2026-03-02 | 2026-07-30 | 79 |
| Mateus Macedo Pacheco | 11942554244 | Preenchimento facial | 2025-10-13 | 2026-08-09 | 69 |
| Natália Guimarães Moura | 11971447855 | Preenchimento labial | 2025-12-08 | 2026-09-04 | 43 |

## [03] Faturamento, custo de locação, despesas e margem por unidade e mês

Total de linhas: **39**

| ano_mes | nome_clinica | faturamento | dias_com_atendimento | custo_locacao | despesas | margem |
|---|---|---|---|---|---|---|
| 2025-10 | Unidade Mogi das Cruzes | 11555.00 | 8 | 2000.00 | 172.00 | 9383.00 |
| 2025-10 | Unidade Mooca | 5085.00 | 4 | 1400.00 | 150.00 | 3535.00 |
| 2025-10 | Unidade Tatuapé | 5620.00 | 3 | 1200.00 | 246.00 | 4174.00 |
| 2025-11 | Unidade Mogi das Cruzes | 7440.00 | 4 | 1000.00 | 112.00 | 6328.00 |
| 2025-11 | Unidade Mooca | 9400.00 | 5 | 1750.00 | 110.00 | 7540.00 |
| 2025-11 | Unidade Tatuapé | 8870.00 | 7 | 2800.00 | 124.00 | 5946.00 |
| 2025-12 | Unidade Mogi das Cruzes | 7740.00 | 4 | 1000.00 | 134.00 | 6606.00 |
| 2025-12 | Unidade Mooca | 6500.00 | 4 | 1400.00 | 134.00 | 4966.00 |
| 2025-12 | Unidade Tatuapé | 10470.00 | 6 | 2400.00 | 178.00 | 7892.00 |
| 2026-01 | Unidade Mogi das Cruzes | 17050.00 | 7 | 1750.00 | 647.00 | 14653.00 |

## [04] Faturamento por procedimento no período (GROUP BY)

Total de linhas: **7**

| nome_procedimento | vezes_realizado | faturamento |
|---|---|---|
| Toxina botulínica | 24 | 28080.00 |
| Preenchimento labial | 10 | 13000.00 |
| Skinbooster | 12 | 11115.00 |
| Preenchimento facial | 6 | 8700.00 |
| Tratamento de olheiras | 5 | 7920.00 |
| Bioestimulador | 3 | 6440.00 |
| Avaliação facial | 11 | 1085.00 |

## [05] Ticket médio por unidade (só atendimentos Realizado)

Total de linhas: **3**

| nome_clinica | atendimentos_realizados | faturamento | ticket_medio |
|---|---|---|---|
| Unidade Mogi das Cruzes | 77 | 123350.00 | 1601.95 |
| Unidade Tatuapé | 68 | 99570.00 | 1464.26 |
| Unidade Mooca | 70 | 97205.00 | 1388.64 |

## [06] Pacientes ativos por cidade e bairro, só bairros com 3 ou mais

Total de linhas: **14**

| cidade | bairro | pacientes_ativos |
|---|---|---|
| Mogi das Cruzes | Vila Oliveira | 11 |
| Mogi das Cruzes | Centro | 8 |
| Mogi das Cruzes | Mogilar | 6 |
| Mogi das Cruzes | Braz Cubas | 3 |
| São Paulo | Mooca | 21 |
| São Paulo | Tatuapé | 16 |
| São Paulo | Penha | 8 |
| São Paulo | Vila Prudente | 7 |
| São Paulo | Água Rasa | 6 |
| São Paulo | Belém | 6 |

## [07] Taxa de comparecimento por unidade:

Total de linhas: **3**

| nome_clinica | realizados | faltas | taxa_comparecimento_pct |
|---|---|---|---|
| Unidade Mogi das Cruzes | 77 | 4 | 95.1 |
| Unidade Tatuapé | 68 | 8 | 89.5 |
| Unidade Mooca | 70 | 10 | 87.5 |

## [08] Estoque atual de todos os insumos ativos, com alerta de mínimo

Total de linhas: **22**

| nome_insumo | marca | unidade_medida | total_comprado | total_consumido | saldo | estoque_minimo | situacao |
|---|---|---|---|---|---|---|---|
| Anestésico tópico | Genérico | g | 270.00 | 257.50 | 12.50 | 72.50 | ABAIXO DO MÍNIMO |
| Milimetric | Milimetric | mL | 20.00 | 20.00 | 0.00 | 3.00 | ABAIXO DO MÍNIMO |
| Up Ilikia | Ilikia | mL | 67.00 | 67.00 | 0.00 | 4.00 | ABAIXO DO MÍNIMO |
| Água para injeção | Genérico | mL | 300.00 | 226.00 | 74.00 | 50.00 | OK |
| Agulha 30G 13 mm | Genérico | un | 600.00 | 492.00 | 108.00 | 60.00 | OK |
| Algodão | Genérico | g | 500.00 | 100.00 | 400.00 | 200.00 | OK |
| Alur Medical | Alur Medical | mL | 40.00 | 36.00 | 4.00 | 4.00 | OK |
| Botox | Allergan | U | 2800.00 | 2434.00 | 366.00 | 200.00 | OK |
| Botulift | Biolab | U | 800.00 | 627.00 | 173.00 | 100.00 | OK |
| Cânula 25G 50 mm | Genérico | un | 100.00 | 81.00 | 19.00 | 15.00 | OK |

## [09] Alertas de validade: lotes vencidos ou que vencem em até 60 dias

Total de linhas: **4**

| nome_insumo | lote | data_compra | data_validade | dias_para_vencer | situacao | saldo_insumo |
|---|---|---|---|---|---|---|
| PLLA Cimed | PLL250935 | 2025-09-26 | 2026-09-30 | -17 | VENCIDO | 1.00 |
| Alur Medical | ALU260825 | 2026-08-11 | 2026-11-03 | 17 | VENCE EM BREVE | 4.00 |
| Soro fisiológico 0,9% | SOR250910 | 2025-09-28 | 2026-11-19 | 33 | VENCE EM BREVE | 303.50 |
| Letybo | LET260511 | 2026-05-20 | 2026-12-07 | 51 | VENCE EM BREVE | 128.00 |

## [10] Custo estimado de insumos por procedimento e margem estimada

Total de linhas: **7**

| nome_procedimento | preco_tabela | custo_insumos | margem_estimada | margem_pct |
|---|---|---|---|---|
| Tratamento de olheiras | 1600.00 | 605.18 | 994.82 | 62.2 |
| Preenchimento labial | 1300.00 | 530.83 | 769.17 | 59.2 |
| Toxina botulínica | 1200.00 | 736.51 | 463.49 | 38.6 |
| Bioestimulador | 2300.00 | 2084.80 | 215.20 | 9.4 |
| Avaliação facial | 100.00 | 0.00 | 100.00 | 100.0 |
| Preenchimento facial | 1500.00 | 1527.68 | -27.68 | -1.8 |
| Skinbooster | 950.00 | 1283.61 | -333.61 | -35.1 |

## [11] Ranking de origem de captação dos pacientes (GROUP BY com HAVING:

Total de linhas: **4**

| origem_captacao | pacientes | percentual |
|---|---|---|
| Instagram | 62 | 49.2 |
| Indicação | 39 | 31.0 |
| Google | 14 | 11.1 |
| WhatsApp | 7 | 5.6 |

## [12] Novos pacientes por mês (pela data de cadastro)

Total de linhas: **13**

| ano_mes | novos_pacientes |
|---|---|
| 2025-09 | 4 |
| 2025-10 | 14 |
| 2025-11 | 19 |
| 2025-12 | 13 |
| 2026-01 | 18 |
| 2026-02 | 13 |
| 2026-03 | 12 |
| 2026-04 | 5 |
| 2026-05 | 9 |
| 2026-06 | 4 |

## [13] Histórico de atendimentos de um paciente (JOIN de 4 tabelas)

Total de linhas: **4**

| data_hora | nome_clinica | status | nome_procedimento | regiao_aplicada | quantidade_aplicada | valor_cobrado |
|---|---|---|---|---|---|---|
| 2026-06-04 14:00:00 | Unidade Mogi das Cruzes | Realizado | Toxina botulínica | Glabela | 20.00 | 1200.00 |
| 2026-06-04 14:00:00 | Unidade Mogi das Cruzes | Realizado | Preenchimento labial | Contorno labial | 1.00 | 1300.00 |
| 2026-01-05 10:00:00 | Unidade Mogi das Cruzes | Realizado | Avaliação facial | Face | 1.00 | 100.00 |
| 2026-01-05 10:00:00 | Unidade Mogi das Cruzes | Realizado | Toxina botulínica | Glabela e testa | 60.00 | 1200.00 |

## [14] Consumo real x quantidade padrão por procedimento e insumo

Total de linhas: **36**

| nome_procedimento | nome_insumo | unidade_medida | quantidade_padrao | media_consumida | registros |
|---|---|---|---|---|---|
| Bioestimulador | Água para injeção | mL | 8.00 | 8.07 | 28 |
| Bioestimulador | Cânula 25G 50 mm | un | 1.00 | 1.00 | 28 |
| Bioestimulador | Clorexidina alcoólica 0,5% | mL | 5.00 | 5.09 | 29 |
| Bioestimulador | Gaze estéril | un | 4.00 | 4.10 | 29 |
| Bioestimulador | Luva de procedimento | par | 1.00 | 1.00 | 29 |
| Bioestimulador | Sculptra | frasco | 1.00 | 1.00 | 21 |
| Bioestimulador | Seringa 1 mL | un | 2.00 | 1.97 | 29 |
| Preenchimento facial | Agulha 30G 13 mm | un | 1.00 | 1.17 | 35 |
| Preenchimento facial | Anestésico tópico | g | 2.00 | 2.04 | 36 |
| Preenchimento facial | Cânula 25G 50 mm | un | 1.00 | 1.00 | 34 |

## [15] Compras por fornecedor e insumo (JOIN de 3 tabelas): mostra que o

Total de linhas: **31**

| nome_insumo | razao_social | compras | quantidade_total | preco_medio |
|---|---|---|---|---|
| Água para injeção | Delta Exemplo Materiais Hospitalares Ltda | 3 | 300.00 | 0.20 |
| Agulha 30G 13 mm | Delta Exemplo Materiais Hospitalares Ltda | 4 | 400.00 | 0.46 |
| Agulha 30G 13 mm | Beta Exemplo Produtos Médicos Ltda | 2 | 200.00 | 0.46 |
| Algodão | Delta Exemplo Materiais Hospitalares Ltda | 1 | 500.00 | 0.04 |
| Alur Medical | Gama Exemplo Dermocosméticos Ltda | 6 | 24.00 | 547.39 |
| Alur Medical | Beta Exemplo Produtos Médicos Ltda | 4 | 16.00 | 554.61 |
| Anestésico tópico | Gama Exemplo Dermocosméticos Ltda | 6 | 180.00 | 2.50 |
| Anestésico tópico | Beta Exemplo Produtos Médicos Ltda | 3 | 90.00 | 2.50 |
| Botox | Gama Exemplo Dermocosméticos Ltda | 10 | 2000.00 | 14.54 |
| Botox | Alfa Exemplo Distribuidora de Produtos Estéticos Ltda | 4 | 800.00 | 14.41 |

## [16] Pacientes ativos sem nenhum atendimento realizado nos últimos 180 dias

Total de linhas: **45**

| nome_completo | telefone_paciente | origem_captacao |
|---|---|---|
| Aline Vasconcelos Faria | 11905535561 | Instagram |
| Aline Xavier Fontes | 11935026404 | Instagram |
| Ana Esteves Peixoto | 11924590198 | Instagram |
| Bruna Brandão Almeida | 11978864827 | Indicação |
| Carla Macedo Brandão | 11917521105 | Instagram |
| Débora Fontes Cardoso | 11994614334 | Indicação |
| Débora Macedo Macedo | 11941174846 | Google |
| Eduarda Coutinho Lacerda | 11987988911 | Instagram |
| Elisa Macedo Sampaio | 11983957614 | Indicação |
| Elisa Xavier Pacheco | 11976353255 | Indicação |

## [17] Procedimentos com faturamento acima da média dos procedimentos

Total de linhas: **4**

| nome_procedimento | faturamento |
|---|---|
| Toxina botulínica | 92040.00 |
| Bioestimulador | 63020.00 |
| Preenchimento facial | 48525.00 |
| Preenchimento labial | 46540.00 |

## [18] Insumos cujo preço da última compra ficou acima do preço médio

Total de linhas: **8**

| nome_insumo | preco_atual | preco_medio |
|---|---|---|
| Agulha 30G 13 mm | 0.47 | 0.46 |
| Botox | 14.64 | 14.50 |
| Gaze estéril | 0.36 | 0.35 |
| Letybo | 18.01 | 17.47 |
| Milimetric | 591.28 | 589.02 |
| Stim | 741.12 | 728.31 |
| Up Ilikia | 636.22 | 621.74 |
| Yvoire Contour | 1006.90 | 973.07 |

## [19] Faturamento por forma de pagamento (GROUP BY com HAVING:

Total de linhas: **4**

| forma_pagamento | atendimentos | faturamento |
|---|---|---|
| Pix | 89 | 139730.00 |
| Cartão de crédito | 83 | 121125.00 |
| Dinheiro | 22 | 31265.00 |
| Cartão de débito | 21 | 28005.00 |

## [20] Faturamento mensal total (base do gráfico de linha do dashboard)

Total de linhas: **14**

| ano_mes | faturamento | realizados |
|---|---|---|
| 2025-10 | 22260.00 | 16 |
| 2025-11 | 25710.00 | 18 |
| 2025-12 | 24710.00 | 16 |
| 2026-01 | 30940.00 | 21 |
| 2026-02 | 22340.00 | 17 |
| 2026-03 | 40645.00 | 27 |
| 2026-04 | 20885.00 | 13 |
| 2026-05 | 26740.00 | 15 |
| 2026-06 | 22935.00 | 15 |
| 2026-07 | 26585.00 | 19 |
