# Zenith - Relatório de entrega 2

> **Nota (19/10/2026):** os arquivos SQL foram reorganizados depois deste relatório: `banco/zenith_completo.sql`, `banco/zenith_permissoes.sql` (senhas como `TROQUE_ESTA_SENHA`), fontes em `banco/historico/` e scripts do schema de teste em `banco/teste/`.

Execução em 17/10/2026. Schemas: `zenith` (trabalho, **só leitura** nesta etapa)
e `zenith_teste` (testes). Nenhum commit, push, GRANT ou alteração de esquema
foi feito. Nenhum dado de `zenith` foi alterado.

## 0. Diagnóstico (somente leitura)

### (i) Contagem das 14 tabelas

| Tabela | zenith | zenith_teste (antes) | Observação |
|---|---|---|---|
| unidade | 3 | 3 | |
| profissional | 1 | 1 | |
| usuario | **1** | 0 | seu Gerente, criado pelo app em 17/10 às 00:52 (esperado) |
| paciente | 126 | 126 | |
| anamnese | 80 | 80 | |
| procedimento | 7 | 7 | |
| fornecedor | 4 | 4 | |
| insumo | 22 | 22 | |
| procedimento_insumo | 36 | 36 | |
| atendimento | 261 | **260** | falta o id 261 no teste |
| atendimento_procedimento | 321 | **320** | falta o id 321 no teste |
| compra | **147** | 146 | carga = 146; ver abaixo |
| consumo | 1432 | 1432 | |
| lancamento | 89 | 89 | |

**Por que o `zenith_teste` estava defasado (260/320).** Não foi o
`gerar_banco_teste.py` nem uma carga antiga: foi um defeito no
`teste_fluxo_interface.py`. Numa rodada que falhou (12/18, quando o seletor
novo ainda tinha um erro), o Agendado do teste não foi salvo. O teste então
pegou `MAX(id_atendimento)` como "o que eu criei" e recebeu o 261 da carga
original (Agendado em 03/11/2026, item 321). A limpeza do final apagou esse
registro. Corrigido: o teste agora anota o maior id **antes** de salvar e só
registra para limpeza um id realmente novo (`registrar_novo`). O
`zenith_teste` foi recarregado e confere com a carga.

**Diferença encontrada no `zenith` (NÃO alterada, decisão sua):** a compra
id 147, feita pelo app em 17/10/2026 às 00:57, cinco minutos depois da criação
do seu usuário. São 1.500 U de Botulift a R$ 350,00 por U, lote "ASDEFDS234",
validade 17/11/2029. O preço difere muito dos ~R$ 7,60/U da carga e parece um
teste manual. Ela soma 1.500 U ao estoque de Botulift e aparece no Power BI.

### (ii) Bloco 10 em `zenith` ("ANTES")

```
combinacoes_paciente_procedimento | vencidos | retornaram | pendentes_vencidos | nao_retornaram_total | taxa_retorno_pct | maior_data_prevista
178 | 70 | 71 | 24 | 107 | 65.7 | 2027-07-09
```

### (iii) Agendado já existentes em `zenith` (11)

| id | data e hora | unidade |
|---|---|---|
| 251 | 19/10/2026 09:00 | Mooca |
| 252 | 19/10/2026 09:30 | Mooca |
| 253 | 19/10/2026 14:00 | Mooca |
| 254 | 19/10/2026 14:00 | Tatuapé |
| 255 | 19/10/2026 15:00 | Tatuapé |
| 256 | 19/10/2026 15:00 | Mogi das Cruzes |
| 257 | 19/10/2026 16:00 | Tatuapé |
| 258 | 23/10/2026 10:00 | Mooca |
| 259 | 23/10/2026 14:00 | Mooca |
| 260 | 26/10/2026 13:00 | Mooca |
| 261 | 03/11/2026 14:00 | Tatuapé |

## A. Bug de rolagem: causa e correção

**Reprodução.** Com `event_generate("<MouseWheel>")` em 21 telas e com a roda
real do mouse (Dashboard), apareceram três problemas encadeados:

1. **Causa principal: o `CTkScrollableFrame` do CustomTkinter 6.0.0.** Cada
   área rolável registra cinco tratadores **globais** (`bind_all`: um da roda e
   quatro da tecla Shift) e nunca os remove. Eles se acumulam a cada troca de
   tela, inclusive os de telas já destruídas. Medi 10 tratadores da roda e 8
   de Shift depois de só quatro trocas de tela. Cada giro executava todos, e
   o erro que você via vinha desse componente.
2. **O matplotlib** (gráficos do Dashboard) prende um tratador da roda na
   janela principal (`root.bind("<MouseWheel>", ..., "+")`). Ele continua
   ativo depois que você sai do Dashboard e acessa `event.widget`.
3. **Agendamentos `after()` órfãos:** a tela de login, a busca com espera de
   300 ms e os diálogos agendavam funções que disparavam depois de a tela ser
   destruída. O Tk apaga o comando junto com o widget, e o resultado é o erro
   `invalid command name "...focus_set"`, visto com a roda real.

**Correção na raiz (sem silenciar exceções):**
- **`AreaRolavel`** (`interface/componentes.py`): área rolável própria
  (canvas, moldura interna e barra), **sem nenhum registro global**. Substitui o
  `CTkScrollableFrame` em todo o app, pela função única `caixa_rolagem`.
- **Tratador único da roda** (`Janela._rolar`): rola a área sob o mouse; foi
  removida a gambiarra anterior que trocava o método do componente.
- **Dashboard:** remove o tratador de roda que o matplotlib prende na janela
  (os gráficos não usam a roda).
- **`AgendaSegura.agendar()`:** todo `after()` das telas e diálogos é
  cancelado no `destroy()`.

**Teste** (`teste_rolagem.py`, 26/26):
- 21 telas, em duas voltas, sem exceção do Python e sem erro do Tk;
- as listas longas rolam de fato;
- depois de 21 trocas de tela continua existindo **1** tratador global da roda
  e **0** de Shift;
- a janela fica sem o tratador do matplotlib.

## C. Regra única de retorno

| Termo | Definição |
|---|---|
| data_retorno_prevista | último procedimento Realizado + `intervalo_retorno_dias` |
| retornou | existe Agendado ou Realizado do paciente depois da data do último procedimento |
| vencido | data_retorno_prevista **<** CURDATE() (estritamente anterior a hoje) |
| pendente | vencido **E** NOT retornou (retorno ainda não vencido **não** é pendente) |
| taxa de retorno | vencidos que retornaram / vencidos |

**Onde está a regra:**
- **View, serviço, Início, consulta [02] e `teste_dashboard`:** a view
  `vw_dash_retorno` já usava exatamente essa regra (`< CURDATE()`). O serviço do
  app (`servicos/relatorios.py`), o Início, a consulta [02] e o
  `teste_dashboard` leem a coluna `vencido` da view. **Não foi preciso alterar o
  esquema**: só o comentário da view em `zenith_banco.sql` ganhou o texto da
  regra.
- **Power BI:** o desalinhamento estava na medida, que usava `<= TODAY()`.
  `docs/powerbi_views.md` agora traz as medidas DAX **Retornos vencidos**,
  **Retornos pendentes** e **Taxa de retorno** (`DIVIDE`, nunca soma de
  taxas), sobre a tabela `'zenith vw_dash_retorno'` e a coluna `vencido` da
  view, sem `TODAY()`.

**Os 107 "pendentes"** eram a contagem de todos os pares sem retorno
(`nao_retornaram_total`), inclusive os que ainda não venceram, com datas
previstas até 09/07/2027. A regra nova exige `vencido`, então resolve: no
`zenith`, os pendentes corretos eram 24.

**ANTES x DEPOIS (bloco 10):**

| Métrica | ANTES (`zenith`, sem a agenda nova) | DEPOIS (`zenith_teste`, com a agenda) |
|---|---|---|
| combinações paciente/procedimento | 178 | 178 |
| vencidos | 70 | 70 |
| retornaram | 71 | 126 |
| pendentes vencidos | 24 | 13 |
| não retornaram (total, inclui não vencidos) | 107 | 52 |
| taxa de retorno | 65,7% | 81,4% |
| maior data prevista | 09/07/2027 | 09/07/2027 |

O efeito vem dos 53 Agendado novos: um Agendado depois do último procedimento
conta como "retornou", então 11 pendentes deixaram de ser pendentes.

## D. Agenda futura

- **Período:** 15 dias úteis, de 19/10 a 09/11/2026, sem sábados, domingos e
  02/11 (Finados).
- **Gerados:** 53 Agendado novos (ids 262 a 314) e 62 itens (ids 322 a 383)
  por um gerador aleatório **separado e determinístico** (`SEMENTE + 2`),
  executado depois de todo o resto.
- **Preservação:** os 261 atendimentos e 321 itens existentes ficaram
  idênticos. Conferido por `diff` linha a linha e pelo teste.
- **Características:** valor cobrado = preço de tabela, desconto 0, sem forma
  de pagamento, sem consumo, 1 ou 2 procedimentos por atendimento, unidade
  pelo mesmo padrão de distribuição dos dados.
- **Total de Agendado:** 64. Por dia útil:
  19/10: **7** · 20/10: 4 · 21/10: 5 · 22/10: 4 · 23/10: 4 · 26/10: 5 ·
  27/10: 3 · 28/10: 5 · 29/10: 5 · 30/10: 3 · 03/11: 3 · 04/11: 2 · 05/11: 5 ·
  06/11: 5 · 09/11: 4.
- **Exceção:** **19/10 já tinha 7 na carga original** (acima do alvo de 5).
  Não acrescentei nenhum nesse dia e não removi os existentes; decisão sua.
- **Validação:** `popular_validar.py` ganhou as contagens comparadas com a
  carga, nenhum Agendado em fim de semana ou feriado, nenhum com consumo ou
  pagamento, e pelo menos 2 por dia útil.
- **Agenda e dashboard:** a consulta [01] (bloco 4) mostra a agenda da Mooca
  nos próximos 30 dias com os novos agendamentos. O Dashboard e o Início leem
  as mesmas views.

## E. Arquivos SQL

- `zenith_completo.sql` (gerado por `gerar_sql_completo.py`), nesta ordem:
  - criação (`zenith_banco.sql` sem a seção 6 de permissões, com gatilhos e
    `DELIMITER`);
  - população (`START TRANSACTION ... COMMIT`);
  - as 20 consultas;
  - `COMMIT` final.

  O cabeçalho traz o AVISO em destaque de que o script apaga e recria
  `zenith`, as contagens finais e a observação de que os usuários não estão no
  script (são criados por `python criar_usuario.py`).
- `zenith_permissoes.sql`: os GRANTs já documentados para `zenith_app`
  (SELECT, INSERT e UPDATE em `zenith.*`; DELETE só em
  `atendimento_procedimento` e `procedimento_insumo`) e `zenith_bi` (SELECT),
  com `<SENHA_AQUI>`.
- `zenith_completo_teste.sql`: cópia com o nome do schema trocado **só** nas
  linhas DROP DATABASE, CREATE DATABASE e USE (5 linhas). Os nomes
  "zenith_app" ficaram intactos.
- **E3, validação em `zenith_teste`: PARCIAL.** O zenith_app não tem DROP,
  CREATE nem TRIGGER no `zenith_teste`, então não consegui rodar a criação.
  Não concedi privilégios. O que fiz: recarreguei os **dados** do
  `zenith_teste` com a população nova (DELETE e INSERT, permitidos) e
  conferi:
  - 14 tabelas e 12 views (bloco 2);
  - contagens iguais às do `zenith_populacao.sql` (`popular_validar.py --teste`:
    Tudo certo);
  - as 20 consultas sem erro.

  **Falta rodar a criação de ponta a ponta:** execute `zenith_completo_teste.sql`
  como root no Workbench (ou me autorize um GRANT no `zenith_teste`) e eu repito
  as conferências.

## Contagens finais por tabela (carga = `zenith_teste` hoje)

| Tabela | Linhas |
|---|---|
| unidade | 3 |
| profissional | 1 |
| usuario | 0 |
| paciente | 126 |
| anamnese | 80 |
| procedimento | 7 |
| fornecedor | 4 |
| insumo | 22 |
| procedimento_insumo | 36 |
| atendimento | 314 |
| atendimento_procedimento | 383 |
| compra | 146 |
| consumo | 1432 |
| lancamento | 89 |

## F. Saídas dos blocos 1 a 11 (`zenith_teste`, executado em 17/10/2026 16:34:33)

Saída exata de `python prints_executar.py zenith_teste` (somente leitura). Os
resultados das 20 consultas estão em `docs/resultados_consultas.md`.

```
===== 1. CONTAGEM DE LINHAS (Figura 6) =====
tabela | linhas
unidade | 3
profissional | 1
usuario | 0
paciente | 126
anamnese | 80
procedimento | 7
fornecedor | 4
insumo | 22
procedimento_insumo | 36
atendimento | 314
atendimento_procedimento | 383
compra | 146
consumo | 1432
lancamento | 89

===== 2. ESTRUTURA (esperado: 14 BASE TABLE e 12 VIEW) =====
tipo | quantidade
BASE TABLE | 14
VIEW | 12

===== 3. ATENDIMENTOS POR MÊS E SITUAÇÃO =====
ano_mes | status | atendimentos
2025-10 | Cancelado | 2
2025-10 | Realizado | 16
2025-11 | Faltou | 1
2025-11 | Realizado | 18
2025-12 | Faltou | 2
2025-12 | Realizado | 16
2026-01 | Cancelado | 2
2026-01 | Faltou | 4
2026-01 | Realizado | 21
2026-02 | Faltou | 1
2026-02 | Realizado | 17
2026-03 | Cancelado | 1
2026-03 | Faltou | 1
2026-03 | Realizado | 27
2026-04 | Cancelado | 1
2026-04 | Faltou | 3
2026-04 | Realizado | 13
2026-05 | Cancelado | 1
2026-05 | Faltou | 2
2026-05 | Realizado | 15
2026-06 | Faltou | 2
2026-06 | Realizado | 15
2026-07 | Cancelado | 4
2026-07 | Faltou | 1
2026-07 | Realizado | 19
2026-08 | Cancelado | 1
2026-08 | Faltou | 2
2026-08 | Realizado | 21
2026-09 | Cancelado | 1
2026-09 | Faltou | 1
2026-09 | Realizado | 12
2026-10 | Agendado | 45
2026-10 | Faltou | 2
2026-10 | Realizado | 5
2026-11 | Agendado | 19

===== 4. FIGURA 7: consulta 01, agenda dos próximos 30 dias (Mooca) =====
id_atendimento | data_hora | nome_clinica | paciente | telefone_paciente | status | procedimentos
251 | 2026-10-19 09:00:00 | Unidade Mooca | Mateus Cardoso Rezende | 11915901082 | Agendado | Toxina botulínica
252 | 2026-10-19 09:30:00 | Unidade Mooca | Helena Ramos Pacheco | 11921712768 | Agendado | Toxina botulínica
253 | 2026-10-19 14:00:00 | Unidade Mooca | Tatiana Esteves Macedo | 11965535681 | Agendado | Preenchimento facial
262 | 2026-10-20 11:00:00 | Unidade Mooca | Thiago Antunes Teixeira | 11993113625 | Agendado | Tratamento de olheiras
265 | 2026-10-20 13:00:00 | Unidade Mooca | Diego Valente Lacerda | 11999993218 | Agendado | Tratamento de olheiras
270 | 2026-10-21 14:00:00 | Unidade Mooca | Yasmin Faria Brandão | 11902410060 | Agendado | Preenchimento facial
273 | 2026-10-22 09:00:00 | Unidade Mooca | Fernanda Ramos Guimarães | 11941050014 | Agendado | Tratamento de olheiras
274 | 2026-10-22 09:30:00 | Unidade Mooca | Débora Fontes Cardoso | 11994614334 | Agendado | Tratamento de olheiras
258 | 2026-10-23 10:00:00 | Unidade Mooca | Bruno Queiroz Tavares | 11955845908 | Agendado | Tratamento de olheiras
259 | 2026-10-23 14:00:00 | Unidade Mooca | Carlos Leal Xavier | 11972066384 | Agendado | Preenchimento labial
280 | 2026-10-26 10:00:00 | Unidade Mooca | Rafael Almeida Siqueira | 11953757307 | Agendado | Preenchimento facial
260 | 2026-10-26 13:00:00 | Unidade Mooca | Juliana Nogueira Guimarães | 11961561046 | Agendado | Preenchimento facial

===== 5. FIGURA 8: consulta 02, retornos pendentes =====
nome_completo | telefone_paciente | nome_procedimento | ultima_data | data_retorno_prevista | dias_em_atraso
Natália Antunes Xavier | 11972888797 | Bioestimulador | 2025-11-17 | 2026-05-16 | 154
Raquel Faria Xavier | 11960890501 | Skinbooster | 2026-01-21 | 2026-05-21 | 149
Elisa Macedo Sampaio | 11983957614 | Skinbooster | 2026-01-26 | 2026-05-26 | 144
Rafael Gomes Lacerda | 11967985712 | Bioestimulador | 2025-11-27 | 2026-05-26 | 144
Mateus Macedo Teixeira | 11982477704 | Toxina botulínica | 2026-01-01 | 2026-05-31 | 139
Mariana Xavier Siqueira | 11903729848 | Toxina botulínica | 2026-01-19 | 2026-06-18 | 121
Juliana Ramos Sampaio | 11964694866 | Toxina botulínica | 2026-01-27 | 2026-06-26 | 113
Fernanda Dias Peixoto | 11957042310 | Toxina botulínica | 2026-03-02 | 2026-07-30 | 79
Mateus Macedo Pacheco | 11942554244 | Preenchimento facial | 2025-10-13 | 2026-08-09 | 69
Natália Guimarães Moura | 11971447855 | Preenchimento labial | 2025-12-08 | 2026-09-04 | 43

===== 6. FIGURA 9: consulta 03, margem por unidade e mês (últimos 4 meses) =====
ano_mes | nome_clinica | faturamento | dias_com_atendimento | custo_locacao | despesas | margem
2026-07 | Unidade Mogi das Cruzes | 8800.00 | 4 | 1000.00 | 357.00 | 7443.00
2026-07 | Unidade Mooca | 13560.00 | 9 | 3150.00 | 177.00 | 10233.00
2026-07 | Unidade Tatuapé | 4225.00 | 3 | 1200.00 | 105.00 | 2920.00
2026-08 | Unidade Mogi das Cruzes | 6540.00 | 5 | 1250.00 | 135.00 | 5155.00
2026-08 | Unidade Mooca | 7150.00 | 3 | 1050.00 | 169.00 | 5931.00
2026-08 | Unidade Tatuapé | 16525.00 | 9 | 3600.00 | 118.00 | 12807.00
2026-09 | Unidade Mogi das Cruzes | 7505.00 | 2 | 500.00 | 576.00 | 6429.00
2026-09 | Unidade Mooca | 3785.00 | 2 | 700.00 | 138.00 | 2947.00
2026-09 | Unidade Tatuapé | 8250.00 | 5 | 2000.00 | 120.00 | 6130.00
2026-10 | Unidade Mogi das Cruzes | 5020.00 | 4 | 1000.00 | 114.00 | 3906.00
2026-10 | Unidade Mooca | 0.00 | 0 | 0.00 | 146.00 | -146.00
2026-10 | Unidade Tatuapé | 1600.00 | 1 | 400.00 | 103.00 | 1097.00

===== 7. FIGURA 10: consulta 04, faturamento por procedimento =====
nome_procedimento | vezes_realizado | faturamento
Toxina botulínica | 24 | 28080.00
Preenchimento labial | 10 | 13000.00
Skinbooster | 12 | 11115.00
Preenchimento facial | 6 | 8700.00
Tratamento de olheiras | 5 | 7920.00
Bioestimulador | 3 | 6440.00
Avaliação facial | 11 | 1085.00

===== 8. FIGURA 11: consulta 07, taxa de comparecimento =====
nome_clinica | realizados | faltas | taxa_comparecimento_pct
Unidade Mogi das Cruzes | 77 | 4 | 95.1
Unidade Tatuapé | 68 | 8 | 89.5
Unidade Mooca | 70 | 10 | 87.5

===== 9. FIGURA 12: consulta 08, estoque atual =====
nome_insumo | marca | unidade_medida | total_comprado | total_consumido | saldo | estoque_minimo | situacao
Anestésico tópico | Genérico | g | 270.00 | 257.50 | 12.50 | 72.50 | ABAIXO DO MÍNIMO
Milimetric | Milimetric | mL | 20.00 | 20.00 | 0.00 | 3.00 | ABAIXO DO MÍNIMO
Up Ilikia | Ilikia | mL | 67.00 | 67.00 | 0.00 | 4.00 | ABAIXO DO MÍNIMO
Água para injeção | Genérico | mL | 300.00 | 226.00 | 74.00 | 50.00 | OK
Agulha 30G 13 mm | Genérico | un | 600.00 | 492.00 | 108.00 | 60.00 | OK
Algodão | Genérico | g | 500.00 | 100.00 | 400.00 | 200.00 | OK
Alur Medical | Alur Medical | mL | 40.00 | 36.00 | 4.00 | 4.00 | OK
Botox | Allergan | U | 2800.00 | 2434.00 | 366.00 | 200.00 | OK
Botulift | Biolab | U | 800.00 | 627.00 | 173.00 | 100.00 | OK
Cânula 25G 50 mm | Genérico | un | 100.00 | 81.00 | 19.00 | 15.00 | OK
Clorexidina alcoólica 0,5% | Genérico | mL | 2000.00 | 900.00 | 1100.00 | 500.00 | OK
Gaze estéril | Genérico | un | 900.00 | 830.00 | 70.00 | 60.00 | OK

===== 10. CHECAGEM DO RETORNO =====
combinacoes_paciente_procedimento | vencidos | retornaram | pendentes_vencidos | nao_retornaram_total | taxa_retorno_pct | maior_data_prevista
178 | 70 | 126 | 13 | 52 | 81.4 | 2027-07-09

===== 11. INTEGRIDADE (todas devem retornar 0) =====
checagem | ocorrencias
agendado em fim de semana | 0
agendado no feriado de 02/11/2026 | 0
realizado sem forma de pagamento | 0
realizado sem procedimento | 0
insumo com saldo negativo | 0
agendado com consumo registrado | 0
```

## J. Imagens dos resultados (`docs/prints/`)

Geradas em 17/10/2026 16:24:34 (horário de início; depois disso só foi corrigido o alinhamento de `ano_mes`, sem nova consulta de dados diferente) por `python prints_imagens.py zenith_teste`, a partir do
`zenith_teste` com a carga nova. **São resultados reais das consultas
desenhados como tabela (Pillow), não capturas do Workbench.** Só a
apresentação muda: dinheiro como R$ 1.234,56 e datas como dd/mm/aaaa. Nenhuma
consulta veio vazia.

| Arquivo | Bloco | Linhas | Tamanho (px) |
|---|---|---|---|
| fig06_contagem.png | 1 | 14 | 405 x 648 |
| fig07_agenda.png | 4 | 12 | 1368 x 568 |
| fig08_retornos_pendentes.png | 5 | 10 | 1222 x 488 |
| fig09_margem_unidade.png | 6 | 12 | 1182 x 568 |
| fig10_fat_procedimento.png | 7 | 7 | 586 x 368 |
| fig11_comparecimento.png | 8 | 3 | 756 x 208 |
| fig12_estoque.png | 9 | 12 | 1356 x 529 |

Os blocos 2, 3, 10 e 11 ficam só em texto (acima). As imagens são gravadas
a 220 dpi, para boa resolução no PDF.

## Arquivos criados e alterados

**Criados**
- **SQL:** `docs/prints_consultas.sql`, `zenith_completo.sql`,
  `zenith_completo_teste.sql`, `zenith_permissoes.sql`.
- **Scripts:** `prints_executar.py`, `prints_imagens.py`, `gerar_sql_completo.py`.
- **Testes:** `teste_rolagem.py`, `teste_retorno_agenda.py`.
- **Resultados:** `docs/resultados_consultas.md` e os 7 PNGs em `docs/prints/`.
- **Relatório:** `entrega2.md`.

**Alterados**
- **Interface:** `interface/componentes.py` (AreaRolavel, AgendaSegura),
  `interface/app.py` (tratador único da roda), `interface/telas/base.py`,
  `login.py`, `atendimentos.py` (agendamentos seguros), `dashboard.py`
  (tratador do matplotlib).
- **Dados:** `popular_gerar.py` (agenda futura), `zenith_populacao.sql`
  (regenerado), `popular_validar.py` (`--teste`, contagens, regras da agenda),
  `banco_teste.py` (`recarregar`).
- **Consultas e testes:** `consultas_executar.py` (`--teste`, `--markdown`),
  `teste_fluxo_interface.py` (limpeza só do que o teste criou),
  `testar.bat`.
- **Documentação:** `zenith_banco.sql` (só o comentário da regra de retorno),
  `zenith_banco_teste.sql` (regenerado), `docs/modelo_dados.md`,
  `docs/powerbi_views.md`.
- **Não tocado:** `docs/secoes_5_a_8.md`.

## Resultado de cada suíte de testes (execução real)

| Suíte | Banco | Resultado |
|---|---|---|
| teste_validacoes.py | - | 15/15 |
| teste_formatos.py | - | 37/37 |
| teste_login.py | - | 28/28 |
| teste_conexao.py | zenith | OK (3 unidades) |
| popular_validar.py | zenith | **4 FALHAS**, todas esperadas: atendimento 261 x 314, itens 321 x 383 (a agenda ainda não está no `zenith`), compra 147 x 146 (a compra manual id 147) e 13 dias úteis da agenda com menos de 2 atendimentos. Somem quando o `zenith` for recriado. |
| consultas_executar.py | zenith | 20 consultas, sem erro |
| teste_dashboard.py | zenith | 44/44 |
| popular_validar.py --teste | zenith_teste | Tudo certo |
| consultas_executar.py --teste | zenith_teste | 20 consultas, sem erro |
| teste_paciente.py | zenith_teste | 7 passos OK, registro removido |
| teste_servicos.py | zenith_teste | 27/27 |
| teste_retorno_agenda.py | zenith_teste | 16/16 |
| teste_rolagem.py | zenith_teste | 26/26 |
| teste_fluxo_pacientes.py | zenith_teste | 21/21 |
| teste_fluxo_interface.py | zenith_teste | 18/18 |

O `zenith_teste` terminou igual à carga, e o `zenith` não teve nenhuma
alteração (última alteração: 17/10 às 14:03, o seu login).

## O que NÃO foi testado

- **Uso humano real:** os testes acionam as telas por código. A roda física
  foi usada só no Dashboard; depois o Power BI passou para a frente e
  interrompeu.
- **Tamanho de 1280x720:** esta tela equivale a ~1200x700 com zoom de 150%.
- **Power BI:** as medidas DAX não foram aplicadas no seu arquivo .pbix.
- **`zenith` real:** não foi recriado nem recebeu a agenda nova, por regra.
- **Criação de ponta a ponta do `zenith_completo.sql`:** falta o privilégio de
  DDL no `zenith_teste` (ver E3).

## Decisões que dependem de você

1. **Compra id 147 no `zenith`** (Botulift, 1.500 U a R$ 350,00): é teste
   manual? Ela some quando o `zenith` for recriado pelo `zenith_completo.sql`;
   se for dado que você quer manter, é preciso registrá-la de novo depois.
2. **19/10 com 7 Agendado** (carga original), acima do alvo de 2 a 5: manter,
   ou reduzir? Reduzir mudaria atendimentos existentes.
3. **E3 completo:** rodar `zenith_completo_teste.sql` como root no Workbench
   ou autorizar, por exemplo,
   `GRANT CREATE, DROP, ALTER, INDEX, TRIGGER, CREATE VIEW ON zenith_teste.* TO 'zenith_app'@'localhost';`.
4. **Proposta B** (abaixo): só implemento depois da sua resposta.

## Sequência para recriar o `zenith` (NÃO executada)

1. **Backup** (Prompt de Comando, na pasta `bin` do MySQL; pede a senha do root):
   `mysqldump -u root -p --routines --triggers --databases zenith > "%USERPROFILE%\Documents\zenith_backup_2026-10-17.sql"`
2. **MySQL Workbench, como root:** abrir e executar **`zenith_completo.sql`**
   (apaga e recria `zenith` com estrutura, dados e consultas).
3. **Como root:** abrir `zenith_permissoes.sql`, trocar cada `<SENHA_AQUI>` pela
   senha certa (a do zenith_app é a do `.env`) e executar. Não salve o arquivo
   com as senhas.
4. **Terminal, na pasta do projeto:** `python criar_usuario.py` para criar o
   Gerente de novo (o script não cria usuários).
5. **Abrir o app:** `iniciar.bat`.
6. **Power BI:** Página Inicial > Atualizar. Aplicar as medidas DAX de
   `docs/powerbi_views.md`.

## B. Proposta: corrigir atendimento Realizado (NÃO implementada)

1. **Editável:** forma de pagamento, desconto, observação, região,
   quantidade e valor dos itens; também incluir ou remover itens. Paciente,
   unidade e data só com motivo registrado. Voltar Realizado para Agendado
   continuaria proibido; o caminho seria uma situação nova, "Estornado",
   também a decidir.
2. **Consumos:** ao editar itens, abrir de novo a confirmação de insumos e
   gravar só a **diferença**: um consumo complementar (positivo) ou um
   "estorno" (compra de ajuste ou consumo negativo). Consumo negativo exige
   mudar o CHECK `quantidade > 0` e os gatilhos `trg_consumo_saldo_*`, que hoje
   só conferem saldo ao aumentar o consumo. Riscos: devolver quantidade de um
   lote já vencido, dupla baixa se a edição for salva duas vezes, e
   divergência com o Power BI até a atualização.
3. **Permissões:** a melhor saída é **não** precisar de DELETE em `consumo` e
   usar só lançamentos de ajuste (INSERT), o que preserva o histórico. Se
   preferir apagar e regravar, seria preciso `GRANT DELETE ON zenith.consumo`
   e um gatilho BEFORE DELETE que confira o saldo. Desaconselho, porque o
   histórico se perde.
4. **Forma de pagamento:** continua obrigatória enquanto Realizado; trocar de
   forma é permitido; no "Estornado" passaria a ser opcional.
5. **Auditoria:** `atualizado_em` diz só *quando*, não *quem* nem *o quê*.
   Proponho a tabela `atendimento_alteracao` (id, id_atendimento, id_usuario,
   data_hora, campo, valor_anterior, valor_novo, motivo), gravada pelo serviço
   na mesma transação.
