# Ajustes no painel Power BI (cópia `Dashboard_Zenith_v1.pbip`)

## Formato detectado
- Relatório: **PBIR** (`definition/pages/<página>/visuals/<id>/visual.json`, schema visualContainer 2.14.0, page 2.1.0).
- Modelo: **TMDL** (`Dashboard_Zenith_v1.SemanticModel/definition/tables/*.tmdl`). Editado por texto, mantendo CRLF e tabulação.
- Página: **2560 x 1440**. O layout alvo (1280x720) foi multiplicado por 2 (margem e vão = 32 px).
- Backup completo (antes de qualquer alteração): `Documentos\Dashboard - Zenith - Copia - BACKUP\` (.pbip + .Report + .SemanticModel).
- Observação: o `.pbip` encontrado se chama `Dashboard_Zenith_v1` (não "Dashboard - Zenith - Copia"). Os `.pbix` não foram tocados.

## Medidas (TMDL) — aplicadas no arquivo, nada ficou para criar à mão
| Tabela | Medida | Mudança | Formato |
|---|---|---|---|
| zenith vw_dash_kpis_mensal | Atendimentos realizados | NOVA: `SUM([realizados])` | 0 |
| zenith vw_dash_kpis_mensal | Ticket médio | só formato | R$ #,0 (0 casas) |
| zenith vw_dash_retorno | Dias em atraso | NOVA: `DATEDIFF(MAX([data_retorno_prevista]), TODAY(), DAY)` | 0 |
| zenith vw_dash_retorno | Retornos pendentes | agora exige `vencido = 1` e `retornou = 0` | 0 |
| zenith vw_dash_retorno | Taxa de retorno | retornados ÷ total, só entre os vencidos | 0,0% |
| zenith vw_dash_comparecimento | Taxa de comparecimento | só formato | 0,0% |

Não mexi em fonte de dados, partições, relacionamentos, colunas nem na tabela Meses.

## Visuais alterados (arquivo = pasta em `visuals/`)
- **NOVO `a1c0e0000000000t1tlo`** caixa de texto: "Zenith – Painel gerencial" (18 pt, negrito) + subtítulo (10 pt).
- **Segmentações** `e9c0…` Unidade, `f4ef…` Procedimento, `883b…` Mês: reposicionadas no topo, cabeçalho virou só "Unidade/Procedimento/Mês" em 10 pt (antes "Filtro por …", 15 pt). Continuam em lista suspensa.
- **Cartões** (7, mesma altura e largura): rótulo renomeado por `displayName` (Faturamento total, Margem líquida, Ticket médio, Atendimentos realizados, Taxa de comparecimento, Taxa de retorno, Retornos pendentes). **NOVO `a1c0e00000000000at3d`** = Atendimentos realizados.
- **`9aba…` Colunas por unidade** (é um combo coluna+linha): séries "Faturamento" e "Custo de locação", rótulos de dados em mil, legenda embaixo, subtítulo removido; ordenação decrescente por faturamento (já existia).
- **`cedc…` Faturamento por mês**: marcadores ligados, eixo Y em mil, subtítulo removido, ordem crescente de ano_mes (já existia). Antes ocupava 2140 px de largura no rodapé; agora cabe na linha 2.
- **`21ad…` Rosca**: título "Faturamento por procedimento", legenda desligada, rótulo = Categoria + % do total, posição fora.
- **`6f02…` Barras de bairro**: filtro Top 10 por soma de pacientes_ativos, título e subtítulo "Não responde ao filtro de unidade".
- **`page.json`**: `visualInteractions` — segmentação Unidade → barras de bairro = `NoFilter`.
- **`0940…` Tabela Retornos pendentes**: colunas Paciente, Telefone, Procedimento, Prazo previsto (coluna de data direta, sem hierarquia), Dias em atraso; removido "Soma de retornou"; total desligado; filtros do visual `vencido = 1` e `retornou = 0`; ordem crescente por prazo. (O campo já era `nome_procedimento`; não havia `nome_nome_procedimento` no arquivo.)
- **NOVO `a1c0e0000000000mrgun`** Tabela "Margem por unidade" (`zenith vw_dash_unidade`): Unidade, Faturamento, Custo de locação, Despesas, Margem (somas), total ligado, ordem decrescente por margem.
- **Todos**: título curto em português (12 pt nos gráficos/tabelas), alt text preenchido, `tabOrder`/`z` na ordem de leitura.

## Layout final (px na página 2560x1440)
| tab | visual | x | y | w | h |
|---|---|---|---|---|---|
| 1 | Título (caixa de texto) | 32 | 24 | 1040 | 96 |
| 2 | Segmentação Unidade | 1120 | 32 | 448 | 112 |
| 3 | Segmentação Procedimento | 1600 | 32 | 448 | 112 |
| 4 | Segmentação Mês | 2080 | 32 | 448 | 112 |
| 5 | Faturamento total | 32 | 176 | 329,14 | 160 |
| 6 | Margem líquida | 393,14 | 176 | 329,14 | 160 |
| 7 | Ticket médio | 754,28 | 176 | 329,14 | 160 |
| 8 | Atendimentos realizados | 1115,42 | 176 | 329,14 | 160 |
| 9 | Taxa de comparecimento | 1476,56 | 176 | 329,14 | 160 |
| 10 | Taxa de retorno | 1837,7 | 176 | 329,14 | 160 |
| 11 | Retornos pendentes (cartão) | 2198,84 | 176 | 329,14 | 160 |
| 12 | Faturamento e custo por unidade | 32 | 368 | 800 | 472 |
| 13 | Faturamento por mês | 864 | 368 | 960 | 472 |
| 14 | Faturamento por procedimento | 1856 | 368 | 672 | 472 |
| 15 | Pacientes ativos por bairro (top 10) | 32 | 872 | 800 | 536 |
| 16 | Retornos pendentes (tabela) | 864 | 872 | 960 | 536 |
| 17 | Margem por unidade | 1856 | 872 | 672 | 536 |

## Validação feita (sem abrir o Power BI)
- Todos os JSON do relatório fazem parse; TMDL editado com trechos únicos e CRLF preservado.
- 17 retângulos: nenhuma sobreposição, todos dentro de 2560x1440.
- Todos os campos referenciados (tabela + coluna/medida) existem no modelo; a interação aponta para visuais existentes.

## O que NÃO foi feito e por quê
- **Formato R$ 0 decimais na tabela Margem por unidade**: tabela não tem formato por coluna sem alterar o modelo; `custo_locacao` e `despesas` estão como "Geral" e `faturamento`/`margem` como R$ 1 casa. Ajuste à mão (selecionar coluna no modelo → Formato → Moeda, 0 casas) ou peça para eu criar medidas formatadas.
- **Prazo previsto em data curta**: a coluna está como "Data por extenso" no modelo; não alterei colunas. Ajuste à mão se quiser dd/mm/aaaa.
- **Fonte do valor e rótulo 10 pt dos cartões**: o cartão novo (`cardVisual`) tem estrutura de formatação própria que eu não tinha como confirmar; deixei o padrão do tema (igual em todos). Ajuste à mão em Formatar → Rótulos.
- **Página com `"type": "Tooltip"`**: o `page.json` marca a página como dica de ferramenta. Não alterei (não foi pedido), mas isso pode esconder a página/atrapalhar. Em Formatar página → Informações da página, desligue "Usar como dica de ferramenta" se for o caso.
- O filtro "Advanced" vazio do cartão Taxa de retorno foi mantido como estava.

## Roteiro de conferência ao abrir no Power BI
1. Abriu sem erro? Se houver, cole a mensagem aqui.
2. Os 17 visuais aparecem alinhados em 4 faixas (título/filtros, cartões, linha 2, linha 3), sem nada cortado.
3. Os 7 cartões têm o mesmo tamanho; Ticket médio sem "Mil" e com 0 casas; taxas com 1 casa (ex.: 40,0%).
4. Atendimentos realizados mostra um número coerente (soma de realizados).
5. Colunas por unidade: legenda "Faturamento / Custo de locação" embaixo, rótulos em mil, maior faturamento à esquerda.
6. Faturamento por mês: meses em ordem, marcadores visíveis, eixo em mil.
7. Rosca: rótulos fora com nome + %, sem legenda e sem "(0%)" em excesso (se a opção de posição não pegar, ajuste em Rótulos de detalhe → Posição).
8. Barras de bairro: só 10 bairros; mudar a segmentação Unidade NÃO altera esse visual (Formatar → Editar interações).
9. Tabela Retornos pendentes: 5 colunas, sem total, só vencidos não retornados, prazo mais antigo no topo; Dias em atraso positivo.
10. Tabela Margem por unidade com total; confira e ajuste o formato R$ 0 casas; por fim confira o alt text (Formatar → Geral → Texto alternativo) e a ordem de tabulação (Exibir → Painel Seleção → Ordem de tabulação).
