-- ============================================================
-- ZENITH - Projeto Integrador I (FATEC Ipiranga)
-- Banco de dados: clinica de estetica (HOF) - Dra. Gabriela Saraiva
-- SGBD: MySQL 8.0.16+ (necessario para o CHECK ser aplicado)
-- Versao do script: 1.0 (baseada na proposta de modelo corrigido)
-- ============================================================

DROP DATABASE IF EXISTS zenith;
CREATE DATABASE zenith
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE zenith;

-- ------------------------------------------------------------
-- 1. TABELAS DE APOIO (sem dependencia)
-- ------------------------------------------------------------

CREATE TABLE unidade (
    id_unidade      TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome_clinica    VARCHAR(50)      NOT NULL,
    bairro_unidade  VARCHAR(40)      NOT NULL,
    cidade_unidade  VARCHAR(40)      NOT NULL,
    uf_unidade      CHAR(2)          NOT NULL,
    valor_locacao   DECIMAL(10,2)    NOT NULL,
    CONSTRAINT pk_unidade PRIMARY KEY (id_unidade),
    CONSTRAINT ck_unidade_valor CHECK (valor_locacao >= 0)
) ENGINE=InnoDB;

CREATE TABLE profissional (
    id_profissional TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome_completo   VARCHAR(100)     NOT NULL,
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
    CONSTRAINT pk_paciente PRIMARY KEY (id_paciente),
    CONSTRAINT uq_paciente_cpf UNIQUE (cpf),
    CONSTRAINT ck_paciente_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
    CONSTRAINT ck_paciente_cep CHECK (cep_paciente REGEXP '^[0-9]{8}$')
) ENGINE=InnoDB;

CREATE TABLE procedimento (
    id_procedimento         INT               NOT NULL AUTO_INCREMENT,
    nome_procedimento       VARCHAR(60)       NOT NULL,
    preco_tabela            DECIMAL(10,2)     NOT NULL,
    intervalo_retorno_dias  SMALLINT UNSIGNED NULL,
    CONSTRAINT pk_procedimento PRIMARY KEY (id_procedimento),
    CONSTRAINT ck_procedimento_preco CHECK (preco_tabela >= 0)
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
    CONSTRAINT pk_fornecedor PRIMARY KEY (id_fornecedor),
    CONSTRAINT uq_fornecedor_cnpj UNIQUE (cnpj),
    CONSTRAINT ck_fornecedor_cnpj CHECK (cnpj REGEXP '^[0-9]{14}$')
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 2. TABELAS COM DEPENDENCIA
-- ------------------------------------------------------------

CREATE TABLE insumo (
    id_insumo         INT           NOT NULL AUTO_INCREMENT,
    id_fornecedor     INT           NOT NULL,
    nome_insumo       VARCHAR(60)   NOT NULL,
    marca             VARCHAR(40)   NOT NULL,
    apresentacao      VARCHAR(40)   NOT NULL,
    lote              VARCHAR(30)   NOT NULL,
    data_validade     DATE          NOT NULL,
    qtd_estoque_atual INT           NOT NULL DEFAULT 0,
    preco_insumo      DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_insumo PRIMARY KEY (id_insumo),
    CONSTRAINT fk_insumo_fornecedor FOREIGN KEY (id_fornecedor)
        REFERENCES fornecedor (id_fornecedor),
    CONSTRAINT ck_insumo_qtd CHECK (qtd_estoque_atual >= 0),
    CONSTRAINT ck_insumo_preco CHECK (preco_insumo >= 0)
) ENGINE=InnoDB;

CREATE TABLE atendimento (
    id_atendimento  INT              NOT NULL AUTO_INCREMENT,
    id_profissional TINYINT UNSIGNED NOT NULL,
    id_paciente     INT              NOT NULL,
    id_unidade      TINYINT UNSIGNED NOT NULL,
    data_hora       DATETIME         NOT NULL,
    status          VARCHAR(15)      NOT NULL DEFAULT 'Agendado',
    valor_total     DECIMAL(10,2)    NOT NULL DEFAULT 0,
    CONSTRAINT pk_atendimento PRIMARY KEY (id_atendimento),
    CONSTRAINT fk_atend_profissional FOREIGN KEY (id_profissional)
        REFERENCES profissional (id_profissional),
    CONSTRAINT fk_atend_paciente FOREIGN KEY (id_paciente)
        REFERENCES paciente (id_paciente),
    CONSTRAINT fk_atend_unidade FOREIGN KEY (id_unidade)
        REFERENCES unidade (id_unidade),
    CONSTRAINT ck_atend_status CHECK
        (status IN ('Agendado', 'Realizado', 'Cancelado', 'Faltou')),
    CONSTRAINT ck_atend_valor CHECK (valor_total >= 0)
) ENGINE=InnoDB;

CREATE TABLE atendimento_procedimento (
    id_atend_proc       INT           NOT NULL AUTO_INCREMENT,
    id_atendimento      INT           NOT NULL,
    id_procedimento     INT           NOT NULL,
    quantidade_aplicada DECIMAL(6,2)  NOT NULL,
    regiao_aplicada     VARCHAR(30)   NOT NULL,
    valor_cobrado       DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_atend_proc PRIMARY KEY (id_atend_proc),
    CONSTRAINT fk_ap_atendimento FOREIGN KEY (id_atendimento)
        REFERENCES atendimento (id_atendimento),
    CONSTRAINT fk_ap_procedimento FOREIGN KEY (id_procedimento)
        REFERENCES procedimento (id_procedimento),
    CONSTRAINT ck_ap_qtd CHECK (quantidade_aplicada > 0),
    CONSTRAINT ck_ap_valor CHECK (valor_cobrado >= 0)
) ENGINE=InnoDB;

CREATE TABLE movimentacao_estoque (
    id_movimentacao   BIGINT        NOT NULL AUTO_INCREMENT,
    id_insumo         INT           NOT NULL,
    id_atendimento    INT           NULL,   -- NULL em ENTRADA (compra)
    tipo_movimentacao VARCHAR(7)    NOT NULL,
    quantidade        INT           NOT NULL,
    data_movimentacao DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_movimentacao PRIMARY KEY (id_movimentacao),
    CONSTRAINT fk_mov_insumo FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo),
    CONSTRAINT fk_mov_atendimento FOREIGN KEY (id_atendimento)
        REFERENCES atendimento (id_atendimento),
    CONSTRAINT ck_mov_tipo CHECK (tipo_movimentacao IN ('ENTRADA', 'SAIDA')),
    CONSTRAINT ck_mov_qtd CHECK (quantidade > 0)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 3. INDICES (RNF01)
-- PK, FK e UNIQUE ja geram indice no InnoDB.
-- Abaixo, os campos mais filtrados em busca e agenda.
-- ------------------------------------------------------------

CREATE INDEX idx_paciente_nome     ON paciente (nome_completo);
CREATE INDEX idx_paciente_ativo    ON paciente (ativo);
CREATE INDEX idx_atend_data_hora   ON atendimento (data_hora);
CREATE INDEX idx_atend_status      ON atendimento (status);
CREATE INDEX idx_mov_data          ON movimentacao_estoque (data_movimentacao);

-- ------------------------------------------------------------
-- 4. CARGA INICIAL MINIMA
-- ATENCAO: valores marcados como PLACEHOLDER (0.00) nao foram
-- informados pela cliente e devem ser preenchidos antes da
-- demonstracao. Nada abaixo e dado real de preco ou locacao.
-- ------------------------------------------------------------

INSERT INTO unidade (nome_clinica, bairro_unidade, cidade_unidade, uf_unidade, valor_locacao) VALUES
    ('Unidade Mooca',          'Mooca',   'Sao Paulo',        'SP', 0.00),  -- PLACEHOLDER
    ('Unidade Tatuape',        'Tatuape', 'Sao Paulo',        'SP', 0.00),  -- PLACEHOLDER
    ('Unidade Mogi das Cruzes','Centro',  'Mogi das Cruzes',  'SP', 0.00);  -- PLACEHOLDER (bairro a confirmar)

INSERT INTO profissional (nome_completo) VALUES
    ('Gabriela Saraiva');  -- nome completo a confirmar

INSERT INTO procedimento (nome_procedimento, preco_tabela, intervalo_retorno_dias) VALUES
    ('Toxina botulinica',  0.00, NULL),  -- PLACEHOLDER: preco e retorno (doc cita 4 a 6 meses)
    ('Preenchimento facial', 0.00, NULL); -- PLACEHOLDER

-- ------------------------------------------------------------
-- 5. CONFERENCIA RAPIDA
-- ------------------------------------------------------------
-- SHOW TABLES;
-- SELECT * FROM unidade;
