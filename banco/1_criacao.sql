-- ============================================================
-- ZENITH - Projeto Integrador (FATEC)
-- Banco de dados: clinica de harmonizacao orofacial - Dra. Gabriela Saraiva
-- SGBD: MySQL 8.0.16+ (necessario para o CHECK ser aplicado)
-- Versao do script: 2.0
--
-- ATENCAO: este script APAGA o banco zenith e o recria vazio.
-- Faca o backup antes.
-- Os dados sao carregados depois por 2_populacao.sql.
-- Execute como root no MySQL Workbench.
-- ============================================================

DROP DATABASE IF EXISTS zenith;
CREATE DATABASE zenith
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE zenith;

-- ------------------------------------------------------------
-- 1. TABELAS SEM DEPENDENCIA
-- ------------------------------------------------------------

CREATE TABLE unidade (
    id_unidade      TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome_clinica    VARCHAR(50)      NOT NULL,
    bairro_unidade  VARCHAR(40)      NOT NULL,
    cidade_unidade  VARCHAR(40)      NOT NULL,
    uf_unidade      CHAR(2)          NOT NULL,
    -- SUPOSICAO: valor da locacao por DIA de uso da sala (ver vw_dash_unidade).
    -- A regra de cobranca da locacao NAO foi confirmada pela cliente.
    valor_locacao   DECIMAL(10,2)    NOT NULL DEFAULT 0,
    ativo           BOOLEAN          NOT NULL DEFAULT TRUE,
    criado_em       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_unidade PRIMARY KEY (id_unidade),
    CONSTRAINT uq_unidade_nome UNIQUE (nome_clinica),
    CONSTRAINT ck_unidade_valor CHECK (valor_locacao >= 0),
    CONSTRAINT ck_unidade_uf CHECK (uf_unidade REGEXP '^[A-Z]{2}$')
) ENGINE=InnoDB;

CREATE TABLE profissional (
    id_profissional TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome_completo   VARCHAR(100)     NOT NULL,
    ativo           BOOLEAN          NOT NULL DEFAULT TRUE,
    criado_em       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_profissional PRIMARY KEY (id_profissional)
) ENGINE=InnoDB;

CREATE TABLE paciente (
    id_paciente       INT           NOT NULL AUTO_INCREMENT,
    nome_completo     VARCHAR(100)  NOT NULL,
    cpf               CHAR(11)      NOT NULL,
    data_nasc         DATE          NOT NULL,
    telefone_paciente VARCHAR(11)   NOT NULL,
    email_paciente    VARCHAR(100)  NULL,
    cep_paciente      CHAR(8)       NOT NULL,
    endereco_paciente VARCHAR(100)  NOT NULL,
    bairro_paciente   VARCHAR(40)   NOT NULL,
    cidade_paciente   VARCHAR(40)   NOT NULL,
    origem_captacao   VARCHAR(30)   NOT NULL,
    ativo             BOOLEAN       NOT NULL DEFAULT TRUE,
    criado_em         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_paciente PRIMARY KEY (id_paciente),
    CONSTRAINT uq_paciente_cpf UNIQUE (cpf),
    CONSTRAINT ck_paciente_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
    CONSTRAINT ck_paciente_cep CHECK (cep_paciente REGEXP '^[0-9]{8}$'),
    CONSTRAINT ck_paciente_telefone CHECK (telefone_paciente REGEXP '^[0-9]{10,11}$'),
    CONSTRAINT ck_paciente_email CHECK (email_paciente IS NULL
                                        OR email_paciente LIKE '%_@_%._%')
) ENGINE=InnoDB;

CREATE TABLE procedimento (
    id_procedimento         INT               NOT NULL AUTO_INCREMENT,
    nome_procedimento       VARCHAR(60)       NOT NULL,
    preco_tabela            DECIMAL(10,2)     NOT NULL,
    intervalo_retorno_dias  SMALLINT UNSIGNED NULL,   -- NULL = sem retorno previsto
    ativo                   BOOLEAN           NOT NULL DEFAULT TRUE,
    criado_em               DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em           DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP
                                              ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_procedimento PRIMARY KEY (id_procedimento),
    CONSTRAINT uq_procedimento_nome UNIQUE (nome_procedimento),
    CONSTRAINT ck_procedimento_preco CHECK (preco_tabela >= 0),
    CONSTRAINT ck_procedimento_retorno CHECK (intervalo_retorno_dias IS NULL
                                              OR intervalo_retorno_dias > 0)
) ENGINE=InnoDB;

CREATE TABLE fornecedor (
    id_fornecedor        INT          NOT NULL AUTO_INCREMENT,
    razao_social         VARCHAR(100) NOT NULL,
    cnpj                 CHAR(14)     NOT NULL,
    telefone_fornecedor  VARCHAR(11)  NOT NULL,
    cep_fornecedor       CHAR(8)      NOT NULL,
    endereco_fornecedor  VARCHAR(100) NOT NULL,
    bairro_fornecedor    VARCHAR(40)  NOT NULL,
    cidade_fornecedor    VARCHAR(40)  NOT NULL,
    ativo                BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                      ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_fornecedor PRIMARY KEY (id_fornecedor),
    CONSTRAINT uq_fornecedor_cnpj UNIQUE (cnpj),
    CONSTRAINT ck_fornecedor_cnpj CHECK (cnpj REGEXP '^[0-9]{14}$'),
    CONSTRAINT ck_fornecedor_cep CHECK (cep_fornecedor REGEXP '^[0-9]{8}$'),
    CONSTRAINT ck_fornecedor_telefone CHECK (telefone_fornecedor REGEXP '^[0-9]{10,11}$')
) ENGINE=InnoDB;

CREATE TABLE insumo (
    id_insumo       INT           NOT NULL AUTO_INCREMENT,
    nome_insumo     VARCHAR(60)   NOT NULL,
    marca           VARCHAR(40)   NOT NULL,
    apresentacao    VARCHAR(40)   NOT NULL,     -- ex.: 'Frasco 100U', 'Seringa 1,0 mL'
    unidade_medida  VARCHAR(10)   NOT NULL,     -- unidade do estoque: 'U', 'mL', 'frasco'...
    estoque_minimo  DECIMAL(10,2) NOT NULL DEFAULT 0,
    ativo           BOOLEAN       NOT NULL DEFAULT TRUE,
    criado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_insumo PRIMARY KEY (id_insumo),
    CONSTRAINT uq_insumo UNIQUE (nome_insumo, marca, apresentacao),
    CONSTRAINT ck_insumo_minimo CHECK (estoque_minimo >= 0)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 2. TABELAS COM DEPENDENCIA
-- ------------------------------------------------------------

CREATE TABLE usuario (
    id_usuario        INT              NOT NULL AUTO_INCREMENT,
    nome              VARCHAR(100)     NOT NULL,
    email             VARCHAR(100)     NOT NULL,
    senha_hash        VARCHAR(100)     NOT NULL,   -- bcrypt; nunca a senha em texto
    perfil            VARCHAR(15)      NOT NULL,
    -- Vinculo opcional: usuario com perfil Profissional aponta para o seu
    -- cadastro de profissional (usado na anamnese e nos atendimentos).
    id_profissional   TINYINT UNSIGNED NULL,
    ativo             BOOLEAN          NOT NULL DEFAULT TRUE,
    tentativas_falhas TINYINT UNSIGNED NOT NULL DEFAULT 0,
    bloqueado_ate     DATETIME         NULL,
    ultimo_acesso     DATETIME         NULL,
    criado_em         DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                       ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_email UNIQUE (email),
    CONSTRAINT fk_usuario_profissional FOREIGN KEY (id_profissional)
        REFERENCES profissional (id_profissional),
    CONSTRAINT ck_usuario_perfil CHECK (perfil IN ('Gerente', 'Atendente', 'Profissional')),
    CONSTRAINT ck_usuario_hash CHECK (senha_hash LIKE '$2%' AND CHAR_LENGTH(senha_hash) >= 59)
) ENGINE=InnoDB;

CREATE TABLE anamnese (
    id_anamnese          INT              NOT NULL AUTO_INCREMENT,
    id_paciente          INT              NOT NULL,
    id_profissional      TINYINT UNSIGNED NOT NULL,
    data_registro        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    queixa_principal     VARCHAR(500)     NOT NULL,
    historico_saude      TEXT             NULL,
    alergias             VARCHAR(500)     NULL,
    medicamentos_em_uso  VARCHAR(500)     NULL,
    observacoes          TEXT             NULL,
    criado_em            DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                          ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_anamnese PRIMARY KEY (id_anamnese),
    CONSTRAINT fk_anamnese_paciente FOREIGN KEY (id_paciente)
        REFERENCES paciente (id_paciente),
    CONSTRAINT fk_anamnese_profissional FOREIGN KEY (id_profissional)
        REFERENCES profissional (id_profissional)
) ENGINE=InnoDB;

CREATE TABLE atendimento (
    id_atendimento  INT              NOT NULL AUTO_INCREMENT,
    id_profissional TINYINT UNSIGNED NOT NULL,
    id_paciente     INT              NOT NULL,
    id_unidade      TINYINT UNSIGNED NOT NULL,
    data_hora       DATETIME         NOT NULL,
    status          VARCHAR(15)      NOT NULL DEFAULT 'Agendado',
    forma_pagamento VARCHAR(20)      NULL,          -- NULL enquanto nao pago
    desconto        DECIMAL(10,2)    NOT NULL DEFAULT 0,
    observacao      VARCHAR(255)     NULL,
    criado_em       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_atendimento PRIMARY KEY (id_atendimento),
    CONSTRAINT fk_atend_profissional FOREIGN KEY (id_profissional)
        REFERENCES profissional (id_profissional),
    CONSTRAINT fk_atend_paciente FOREIGN KEY (id_paciente)
        REFERENCES paciente (id_paciente),
    CONSTRAINT fk_atend_unidade FOREIGN KEY (id_unidade)
        REFERENCES unidade (id_unidade),
    CONSTRAINT ck_atend_status CHECK
        (status IN ('Agendado', 'Realizado', 'Cancelado', 'Faltou')),
    CONSTRAINT ck_atend_pagamento CHECK (forma_pagamento IS NULL OR forma_pagamento IN
        ('Pix', 'Cartão de crédito', 'Cartão de débito', 'Dinheiro')),
    CONSTRAINT ck_atend_desconto CHECK (desconto >= 0)
) ENGINE=InnoDB;

CREATE TABLE atendimento_procedimento (
    id_atend_proc       INT           NOT NULL AUTO_INCREMENT,
    id_atendimento      INT           NOT NULL,
    id_procedimento     INT           NOT NULL,
    quantidade_aplicada DECIMAL(6,2)  NOT NULL,
    regiao_aplicada     VARCHAR(30)   NOT NULL,
    valor_cobrado       DECIMAL(10,2) NOT NULL,
    criado_em           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                      ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_atend_proc PRIMARY KEY (id_atend_proc),
    CONSTRAINT fk_ap_atendimento FOREIGN KEY (id_atendimento)
        REFERENCES atendimento (id_atendimento),
    CONSTRAINT fk_ap_procedimento FOREIGN KEY (id_procedimento)
        REFERENCES procedimento (id_procedimento),
    CONSTRAINT ck_ap_qtd CHECK (quantidade_aplicada > 0),
    CONSTRAINT ck_ap_valor CHECK (valor_cobrado >= 0)
) ENGINE=InnoDB;

-- Procedimento x Insumo: quanto cada procedimento consome de cada insumo.
-- quantidade_padrao e um valor SUGERIDO, editavel pela profissional a
-- qualquer momento. Altera-lo NAO muda consumos ja registrados: o consumo
-- guarda a quantidade real usada.
CREATE TABLE procedimento_insumo (
    id_procedimento    INT           NOT NULL,
    id_insumo          INT           NOT NULL,
    quantidade_padrao  DECIMAL(10,2) NOT NULL,
    criado_em          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_procedimento_insumo PRIMARY KEY (id_procedimento, id_insumo),
    CONSTRAINT fk_pi_procedimento FOREIGN KEY (id_procedimento)
        REFERENCES procedimento (id_procedimento),
    CONSTRAINT fk_pi_insumo FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo),
    CONSTRAINT ck_pi_qtd CHECK (quantidade_padrao > 0)
) ENGINE=InnoDB;

-- Fornecedor x Insumo (N:M): cada compra e uma entrada de estoque.
-- Lote, validade e preco pertencem a compra, nao ao insumo.
CREATE TABLE compra (
    id_compra       INT           NOT NULL AUTO_INCREMENT,
    id_fornecedor   INT           NOT NULL,
    id_insumo       INT           NOT NULL,
    data_compra     DATE          NOT NULL,
    quantidade      DECIMAL(10,2) NOT NULL,   -- na unidade_medida do insumo
    preco_unitario  DECIMAL(10,2) NOT NULL,   -- por unidade_medida
    lote            VARCHAR(30)   NOT NULL,
    data_validade   DATE          NOT NULL,
    criado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_compra PRIMARY KEY (id_compra),
    CONSTRAINT fk_compra_fornecedor FOREIGN KEY (id_fornecedor)
        REFERENCES fornecedor (id_fornecedor),
    CONSTRAINT fk_compra_insumo FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo),
    CONSTRAINT ck_compra_qtd CHECK (quantidade > 0),
    CONSTRAINT ck_compra_preco CHECK (preco_unitario >= 0),
    CONSTRAINT ck_compra_validade CHECK (data_validade > data_compra)
) ENGINE=InnoDB;

-- Insumo x Atendimento: cada consumo e uma saida de estoque com a
-- quantidade REAL usada. id_atendimento NULL = consumo avulso
-- (perda, vencimento, teste...), e entao o motivo em observacao e obrigatorio.
CREATE TABLE consumo (
    id_consumo      INT           NOT NULL AUTO_INCREMENT,
    id_insumo       INT           NOT NULL,
    id_atendimento  INT           NULL,
    quantidade      DECIMAL(10,2) NOT NULL,
    data_consumo    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacao      VARCHAR(255)  NULL,
    criado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_consumo PRIMARY KEY (id_consumo),
    CONSTRAINT fk_consumo_insumo FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo),
    CONSTRAINT fk_consumo_atendimento FOREIGN KEY (id_atendimento)
        REFERENCES atendimento (id_atendimento),
    CONSTRAINT ck_consumo_qtd CHECK (quantidade > 0),
    CONSTRAINT ck_consumo_avulso CHECK (id_atendimento IS NOT NULL
        OR (observacao IS NOT NULL AND CHAR_LENGTH(TRIM(observacao)) > 0))
) ENGINE=InnoDB;

-- Lancamentos financeiros avulsos (despesas e receitas que nao sao
-- atendimentos). id_unidade NULL = lancamento geral, sem unidade.
CREATE TABLE lancamento (
    id_lancamento    INT              NOT NULL AUTO_INCREMENT,
    id_unidade       TINYINT UNSIGNED NULL,
    categoria        VARCHAR(40)      NOT NULL,
    descricao        VARCHAR(200)     NOT NULL,
    valor            DECIMAL(10,2)    NOT NULL,
    data_lancamento  DATE             NOT NULL,
    tipo             VARCHAR(7)       NOT NULL,
    criado_em        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                      ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_lancamento PRIMARY KEY (id_lancamento),
    CONSTRAINT fk_lancamento_unidade FOREIGN KEY (id_unidade)
        REFERENCES unidade (id_unidade),
    CONSTRAINT ck_lancamento_valor CHECK (valor > 0),
    CONSTRAINT ck_lancamento_tipo CHECK (tipo IN ('RECEITA', 'DESPESA'))
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 3. INDICES
-- PK, FK e UNIQUE ja geram indice no InnoDB.
-- Abaixo, os campos mais filtrados em busca, agenda e relatorios.
-- ------------------------------------------------------------

CREATE INDEX idx_paciente_nome      ON paciente (nome_completo);
CREATE INDEX idx_paciente_ativo     ON paciente (ativo);
CREATE INDEX idx_paciente_cidade    ON paciente (cidade_paciente, bairro_paciente);
CREATE INDEX idx_atend_data_hora    ON atendimento (data_hora);
CREATE INDEX idx_atend_status       ON atendimento (status);
CREATE INDEX idx_atend_unidade_data ON atendimento (id_unidade, data_hora);
CREATE INDEX idx_compra_insumo_data ON compra (id_insumo, data_compra);
CREATE INDEX idx_compra_validade    ON compra (data_validade);
CREATE INDEX idx_consumo_data       ON consumo (data_consumo);
CREATE INDEX idx_lancamento_data    ON lancamento (data_lancamento);
CREATE INDEX idx_anamnese_data      ON anamnese (id_paciente, data_registro);

-- ------------------------------------------------------------
-- 4. REGRA DE ESTOQUE NO BANCO: o saldo nunca fica negativo.
-- Saldo de um insumo = soma das compras - soma dos consumos.
-- Os gatilhos recusam qualquer gravacao que deixaria o saldo < 0,
-- mesmo que venha de fora do aplicativo (ex.: futura versao web).
-- ------------------------------------------------------------

DELIMITER $$

CREATE TRIGGER trg_consumo_saldo_insert
BEFORE INSERT ON consumo FOR EACH ROW
BEGIN
    DECLARE v_saldo DECIMAL(12,2);
    SELECT COALESCE((SELECT SUM(quantidade) FROM compra  WHERE id_insumo = NEW.id_insumo), 0)
         - COALESCE((SELECT SUM(quantidade) FROM consumo WHERE id_insumo = NEW.id_insumo), 0)
      INTO v_saldo;
    IF NEW.quantidade > v_saldo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Saldo insuficiente do insumo para este consumo.';
    END IF;
END$$

CREATE TRIGGER trg_consumo_saldo_update
BEFORE UPDATE ON consumo FOR EACH ROW
BEGIN
    DECLARE v_saldo DECIMAL(12,2);
    SELECT COALESCE((SELECT SUM(quantidade) FROM compra  WHERE id_insumo = NEW.id_insumo), 0)
         - COALESCE((SELECT SUM(quantidade) FROM consumo
                     WHERE id_insumo = NEW.id_insumo AND id_consumo <> OLD.id_consumo), 0)
      INTO v_saldo;
    IF NEW.quantidade > v_saldo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Saldo insuficiente do insumo para este consumo.';
    END IF;
END$$

CREATE TRIGGER trg_compra_saldo_update
BEFORE UPDATE ON compra FOR EACH ROW
BEGIN
    DECLARE v_comprado DECIMAL(12,2);
    DECLARE v_consumido DECIMAL(12,2);
    -- recusa reduzir (ou trocar de insumo) uma compra ja consumida
    SELECT COALESCE(SUM(quantidade), 0) INTO v_comprado
      FROM compra WHERE id_insumo = OLD.id_insumo AND id_compra <> OLD.id_compra;
    SELECT COALESCE(SUM(quantidade), 0) INTO v_consumido
      FROM consumo WHERE id_insumo = OLD.id_insumo;
    IF v_comprado + IF(NEW.id_insumo = OLD.id_insumo, NEW.quantidade, 0) < v_consumido THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Alteracao deixaria o saldo do insumo negativo.';
    END IF;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- 5. VIEWS (usadas pelo aplicativo e pelo Power BI)
-- Valores de faturamento consideram SOMENTE atendimentos 'Realizado'.
-- 'Faltou' e 'Cancelado' nunca contam como receita.
-- ------------------------------------------------------------

-- 5.1 Estoque atual de cada insumo (compras - consumos)
CREATE VIEW vw_estoque_atual AS
SELECT i.id_insumo,
       i.nome_insumo,
       i.marca,
       i.apresentacao,
       i.unidade_medida,
       i.estoque_minimo,
       i.ativo,
       COALESCE(c.total_comprado, 0)                                AS total_comprado,
       COALESCE(s.total_consumido, 0)                               AS total_consumido,
       COALESCE(c.total_comprado, 0) - COALESCE(s.total_consumido, 0) AS saldo,
       (COALESCE(c.total_comprado, 0) - COALESCE(s.total_consumido, 0))
           < i.estoque_minimo                                       AS abaixo_minimo
FROM insumo i
LEFT JOIN (SELECT id_insumo, SUM(quantidade) AS total_comprado
             FROM compra GROUP BY id_insumo) c ON c.id_insumo = i.id_insumo
LEFT JOIN (SELECT id_insumo, SUM(quantidade) AS total_consumido
             FROM consumo GROUP BY id_insumo) s ON s.id_insumo = i.id_insumo;

-- 5.2 Compras vencidas ou que vencem em ate 60 dias, de insumos com saldo.
-- SUPOSICAO: nao ha controle FIFO por lote; o saldo mostrado e o do
-- insumo inteiro, nao o que resta daquele lote especifico.
CREATE VIEW vw_alerta_validade AS
SELECT co.id_compra,
       e.id_insumo,
       e.nome_insumo,
       e.marca,
       e.unidade_medida,
       co.lote,
       co.data_compra,
       co.data_validade,
       DATEDIFF(co.data_validade, CURDATE()) AS dias_para_vencer,
       co.data_validade < CURDATE()          AS vencido,
       co.quantidade                         AS quantidade_comprada,
       e.saldo                               AS saldo_insumo
FROM compra co
JOIN vw_estoque_atual e ON e.id_insumo = co.id_insumo
WHERE co.data_validade <= CURDATE() + INTERVAL 60 DAY
  AND e.saldo > 0
  AND e.ativo = TRUE;

-- 5.3 Valor de cada atendimento (itens - desconto). Substitui o antigo
-- campo valor_total. Nunca negativo.
CREATE VIEW vw_valor_atendimento AS
SELECT a.id_atendimento,
       a.id_paciente,
       a.id_unidade,
       a.id_profissional,
       a.data_hora,
       a.status,
       a.forma_pagamento,
       COALESCE(SUM(ap.valor_cobrado), 0)                              AS subtotal,
       a.desconto,
       GREATEST(COALESCE(SUM(ap.valor_cobrado), 0) - a.desconto, 0)    AS valor_total,
       COUNT(ap.id_atend_proc)                                         AS qtd_itens
FROM atendimento a
LEFT JOIN atendimento_procedimento ap ON ap.id_atendimento = a.id_atendimento
GROUP BY a.id_atendimento, a.id_paciente, a.id_unidade, a.id_profissional,
         a.data_hora, a.status, a.forma_pagamento, a.desconto;

-- 5.4 Faturamento: so atendimentos Realizado
CREATE VIEW vw_faturamento AS
SELECT v.id_atendimento,
       v.id_paciente,
       v.id_unidade,
       u.nome_clinica,
       DATE(v.data_hora)                 AS data_atendimento,
       DATE_FORMAT(v.data_hora, '%Y-%m') AS ano_mes,
       v.forma_pagamento,
       v.subtotal,
       v.desconto,
       v.valor_total
FROM vw_valor_atendimento v
JOIN unidade u ON u.id_unidade = v.id_unidade
WHERE v.status = 'Realizado';

-- 5.5 KPIs por mes e unidade (o Power BI e o app somam/filtram por cima)
CREATE VIEW vw_dash_kpis_mensal AS
SELECT DATE_FORMAT(v.data_hora, '%Y-%m')                                  AS ano_mes,
       v.id_unidade,
       u.nome_clinica,
       SUM(v.status = 'Realizado')                                        AS realizados,
       SUM(v.status = 'Faltou')                                           AS faltas,
       SUM(v.status = 'Cancelado')                                        AS cancelados,
       SUM(v.status = 'Agendado')                                         AS agendados,
       SUM(CASE WHEN v.status = 'Realizado' THEN v.valor_total ELSE 0 END) AS faturamento,
       ROUND(SUM(CASE WHEN v.status = 'Realizado' THEN v.valor_total ELSE 0 END)
             / NULLIF(SUM(v.status = 'Realizado'), 0), 2)                 AS ticket_medio,
       COUNT(DISTINCT CASE WHEN v.status = 'Realizado' THEN v.id_paciente END)
                                                                          AS pacientes_atendidos
FROM vw_valor_atendimento v
JOIN unidade u ON u.id_unidade = v.id_unidade
GROUP BY DATE_FORMAT(v.data_hora, '%Y-%m'), v.id_unidade, u.nome_clinica;

-- 5.6 Faturamento, custo de locacao, despesas e margem por unidade e mes.
-- SUPOSICAO (NAO confirmada pela cliente): custo de locacao =
--   unidade.valor_locacao x dias distintos com atendimento Realizado no mes.
-- Para trocar a regra, altere SO a coluna custo_locacao abaixo
-- (ex.: valor fixo mensal = u.valor_locacao).
-- Margem = faturamento - custo_locacao - despesas lancadas para a unidade.
CREATE VIEW vw_dash_unidade AS
SELECT m.ano_mes,
       u.id_unidade,
       u.nome_clinica,
       COALESCE(f.faturamento, 0)                           AS faturamento,
       COALESCE(f.dias_com_atendimento, 0)                  AS dias_com_atendimento,
       u.valor_locacao * COALESCE(f.dias_com_atendimento, 0) AS custo_locacao,
       COALESCE(d.despesas, 0)                              AS despesas,
       COALESCE(f.faturamento, 0)
         - u.valor_locacao * COALESCE(f.dias_com_atendimento, 0)
         - COALESCE(d.despesas, 0)                          AS margem
FROM (SELECT DISTINCT id_unidade, ano_mes FROM vw_faturamento
      UNION
      SELECT DISTINCT id_unidade, DATE_FORMAT(data_lancamento, '%Y-%m')
        FROM lancamento WHERE id_unidade IS NOT NULL) m
JOIN unidade u ON u.id_unidade = m.id_unidade
LEFT JOIN (SELECT id_unidade, ano_mes,
                  SUM(valor_total)                  AS faturamento,
                  COUNT(DISTINCT data_atendimento)  AS dias_com_atendimento
             FROM vw_faturamento GROUP BY id_unidade, ano_mes) f
       ON f.id_unidade = m.id_unidade AND f.ano_mes = m.ano_mes
LEFT JOIN (SELECT id_unidade, DATE_FORMAT(data_lancamento, '%Y-%m') AS ano_mes,
                  SUM(valor) AS despesas
             FROM lancamento WHERE tipo = 'DESPESA' AND id_unidade IS NOT NULL
             GROUP BY id_unidade, DATE_FORMAT(data_lancamento, '%Y-%m')) d
       ON d.id_unidade = m.id_unidade AND d.ano_mes = m.ano_mes;

-- 5.7 Faturamento por procedimento, mes e unidade. O desconto do
-- atendimento e repartido entre os itens na proporcao do valor cobrado,
-- para que a soma por procedimento feche com vw_faturamento.
CREATE VIEW vw_dash_procedimento AS
SELECT DATE_FORMAT(v.data_hora, '%Y-%m') AS ano_mes,
       v.id_unidade,
       p.id_procedimento,
       p.nome_procedimento,
       COUNT(*)                          AS quantidade_realizada,
       ROUND(SUM(ap.valor_cobrado
                 - v.desconto * ap.valor_cobrado / NULLIF(v.subtotal, 0)), 2)
                                         AS faturamento
FROM vw_valor_atendimento v
JOIN atendimento_procedimento ap ON ap.id_atendimento = v.id_atendimento
JOIN procedimento p ON p.id_procedimento = ap.id_procedimento
WHERE v.status = 'Realizado'
GROUP BY DATE_FORMAT(v.data_hora, '%Y-%m'), v.id_unidade,
         p.id_procedimento, p.nome_procedimento;

-- 5.8 Retornos (REGRA UNICA, igual no app, nas consultas e no Power BI):
-- por paciente ativo e procedimento com intervalo_retorno_dias definido,
--   data_retorno_prevista = data do ultimo procedimento Realizado + intervalo
--   retornou = existe atendimento Agendado ou Realizado do paciente
--              depois da data desse ultimo procedimento
--   vencido  = data_retorno_prevista < CURDATE()  (estritamente antes de hoje)
--   pendente = vencido AND NOT retornou  (retorno ainda nao vencido NAO e pendente)
--   taxa de retorno = vencidos que retornaram / vencidos
CREATE VIEW vw_dash_retorno AS
SELECT x.id_paciente,
       pa.nome_completo,
       pa.telefone_paciente,
       x.id_procedimento,
       pr.nome_procedimento,
       x.id_unidade,
       x.ultima_data,
       DATE_ADD(x.ultima_data, INTERVAL pr.intervalo_retorno_dias DAY) AS data_retorno_prevista,
       EXISTS (SELECT 1 FROM atendimento a2
                WHERE a2.id_paciente = x.id_paciente
                  AND a2.status IN ('Agendado', 'Realizado')
                  AND DATE(a2.data_hora) > x.ultima_data)              AS retornou,
       DATE_ADD(x.ultima_data, INTERVAL pr.intervalo_retorno_dias DAY) < CURDATE()
                                                                       AS vencido
FROM (SELECT a.id_paciente, ap.id_procedimento,
             MAX(DATE(a.data_hora)) AS ultima_data,
             SUBSTRING_INDEX(GROUP_CONCAT(a.id_unidade ORDER BY a.data_hora DESC), ',', 1)
                 + 0 AS id_unidade
        FROM atendimento a
        JOIN atendimento_procedimento ap ON ap.id_atendimento = a.id_atendimento
       WHERE a.status = 'Realizado'
       GROUP BY a.id_paciente, ap.id_procedimento) x
JOIN procedimento pr ON pr.id_procedimento = x.id_procedimento
JOIN paciente pa     ON pa.id_paciente = x.id_paciente
WHERE pr.intervalo_retorno_dias IS NOT NULL
  AND pa.ativo = TRUE;

-- 5.9 Pacientes por cidade e bairro
CREATE VIEW vw_dash_pacientes_cidade_bairro AS
SELECT cidade_paciente AS cidade,
       bairro_paciente AS bairro,
       SUM(ativo = TRUE) AS pacientes_ativos,
       COUNT(*)          AS pacientes_total
FROM paciente
GROUP BY cidade_paciente, bairro_paciente;

-- 5.10 Comparecimento = realizados / (realizados + faltas), por mes e unidade.
-- Cancelados nao entram na conta (foram desmarcados com antecedencia).
CREATE VIEW vw_dash_comparecimento AS
SELECT DATE_FORMAT(data_hora, '%Y-%m') AS ano_mes,
       id_unidade,
       SUM(status = 'Realizado') AS realizados,
       SUM(status = 'Faltou')    AS faltas,
       ROUND(SUM(status = 'Realizado')
             / NULLIF(SUM(status IN ('Realizado', 'Faltou')), 0), 4) AS taxa_comparecimento
FROM atendimento
GROUP BY DATE_FORMAT(data_hora, '%Y-%m'), id_unidade;

-- 5.11 Preco atual de cada insumo = preco unitario da compra mais recente
CREATE VIEW vw_preco_insumo_atual AS
SELECT id_insumo, preco_unitario, data_compra
FROM (SELECT id_insumo, preco_unitario, data_compra,
             ROW_NUMBER() OVER (PARTITION BY id_insumo
                                ORDER BY data_compra DESC, id_compra DESC) AS ordem
        FROM compra) t
WHERE ordem = 1;

-- 5.12 Custo estimado de insumos por procedimento
-- (quantidade padrao x preco da compra mais recente).
CREATE VIEW vw_custo_procedimento AS
SELECT p.id_procedimento,
       p.nome_procedimento,
       p.preco_tabela,
       ROUND(COALESCE(SUM(pi.quantidade_padrao * pa.preco_unitario), 0), 2) AS custo_insumos,
       ROUND(p.preco_tabela
             - COALESCE(SUM(pi.quantidade_padrao * pa.preco_unitario), 0), 2) AS margem_estimada,
       COUNT(pi.id_insumo)                                                   AS qtd_insumos,
       SUM(pi.id_insumo IS NOT NULL AND pa.preco_unitario IS NULL)           AS insumos_sem_preco
FROM procedimento p
LEFT JOIN procedimento_insumo pi ON pi.id_procedimento = p.id_procedimento
LEFT JOIN vw_preco_insumo_atual pa ON pa.id_insumo = pi.id_insumo
GROUP BY p.id_procedimento, p.nome_procedimento, p.preco_tabela;

-- ------------------------------------------------------------
-- 6. PERMISSOES (execute como root, depois de criar o banco)
-- zenith_app le, inclui e altera; NAO apaga e NAO altera estrutura.
-- O usuario ja existe; se for preciso recria-lo, use
--   CREATE USER 'zenith_app'@'localhost' IDENTIFIED BY '<senha do .env>';
-- (nunca grave a senha neste arquivo).
-- ------------------------------------------------------------
-- REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'zenith_app'@'localhost';
-- GRANT SELECT, INSERT, UPDATE ON zenith.* TO 'zenith_app'@'localhost';
-- -- SELECT em zenith.* ja inclui todas as views (vw_*).
-- FLUSH PRIVILEGES;
-- SHOW GRANTS FOR 'zenith_app'@'localhost';

-- ------------------------------------------------------------
-- 7. CONFERENCIA RAPIDA
-- ------------------------------------------------------------
-- SHOW FULL TABLES;
-- SELECT * FROM vw_estoque_atual;
