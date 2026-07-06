DROP TABLE IF EXISTS arbitrage_opportunity CASCADE;
DROP TABLE IF EXISTS market_price CASCADE;
DROP TABLE IF EXISTS funding_rate CASCADE;
DROP TABLE IF EXISTS market CASCADE;
DROP TABLE IF EXISTS token CASCADE;
DROP TABLE IF EXISTS exchange CASCADE;

CREATE TABLE exchange (
    exchange_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    code        VARCHAR(10)  NOT NULL UNIQUE,
    api_url     VARCHAR(255)
);

CREATE TABLE token (
    token_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol     VARCHAR(10) NOT NULL UNIQUE,
    name       VARCHAR(50) NOT NULL,
    asset_type VARCHAR(20),
    CONSTRAINT token_asset_type_check
        CHECK (asset_type IS NULL OR asset_type IN ('coin', 'stablecoin', 'token'))
);

CREATE TABLE market (
    market_id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    exchange_id      INTEGER NOT NULL REFERENCES exchange(exchange_id) ON DELETE CASCADE,
    token_id         INTEGER NOT NULL REFERENCES token(token_id) ON DELETE CASCADE,
    symbol           VARCHAR(20) NOT NULL,
    funding_interval SMALLINT NOT NULL,

    CONSTRAINT market_unique_exchange_token UNIQUE (exchange_id, token_id),
    CONSTRAINT market_unique_exchange_symbol UNIQUE (exchange_id, symbol),
    CONSTRAINT market_funding_interval_check CHECK (funding_interval IN (1, 4, 8, 12, 24))
);

-- SCD Type 2: храним историю изменений funding rate.
-- Актуальная запись для рынка имеет is_current = true и effective_to IS NULL.
CREATE TABLE funding_rate (
    funding_rate_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    market_id       INTEGER NOT NULL REFERENCES market(market_id) ON DELETE CASCADE,
    rate_value      NUMERIC(9, 6) NOT NULL,
    effective_from  TIMESTAMPTZ NOT NULL,
    effective_to    TIMESTAMPTZ,
    is_current      BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT funding_rate_period_check
        CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT funding_rate_value_check
        CHECK (rate_value BETWEEN -1 AND 1),
    CONSTRAINT funding_rate_unique_market_from UNIQUE (market_id, effective_from)
);

-- Только одна актуальная funding-rate запись на рынок.
CREATE UNIQUE INDEX funding_rate_one_current_per_market
    ON funding_rate(market_id)
    WHERE is_current = TRUE;

CREATE TABLE market_price (
    price_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    market_id   INTEGER NOT NULL REFERENCES market(market_id) ON DELETE CASCADE,
    price       NUMERIC(20, 8) NOT NULL,
    last_update TIMESTAMPTZ NOT NULL,

    CONSTRAINT market_price_positive_check CHECK (price > 0),
    CONSTRAINT market_price_unique_market_time UNIQUE (market_id, last_update)
);

-- Таблица с уже рассчитанными возможностями.
-- В схеме лучше хранить timestamp как время расчёта, а не FK на несуществующий snapshot.
CREATE TABLE arbitrage_opportunity (
    arbitrage_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    market1_id   INTEGER NOT NULL REFERENCES market(market_id) ON DELETE CASCADE,
    market2_id   INTEGER NOT NULL REFERENCES market(market_id) ON DELETE CASCADE,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    funding_rate1 NUMERIC(9, 6) NOT NULL,
    funding_rate2 NUMERIC(9, 6) NOT NULL,
    price1        NUMERIC(20, 8) NOT NULL,
    price2        NUMERIC(20, 8) NOT NULL,

    funding_spread NUMERIC(9, 6) NOT NULL,
    price_spread_pct NUMERIC(12, 6) NOT NULL,
    expected_profit_pct NUMERIC(12, 6) NOT NULL,

    CONSTRAINT arbitrage_different_markets_check CHECK (market1_id <> market2_id),
    CONSTRAINT arbitrage_unique_pair_time UNIQUE (market1_id, market2_id, calculated_at)
);

CREATE INDEX idx_market_exchange_id ON market(exchange_id);
CREATE INDEX idx_market_token_id ON market(token_id);
CREATE INDEX idx_funding_rate_market_time ON funding_rate(market_id, effective_from DESC);
CREATE INDEX idx_market_price_market_time ON market_price(market_id, last_update DESC);
CREATE INDEX idx_arbitrage_profit ON arbitrage_opportunity(expected_profit_pct DESC);

COMMENT ON TABLE funding_rate IS 'История funding rate по рынкам в формате SCD Type 2';
COMMENT ON TABLE arbitrage_opportunity IS 'Рассчитанные потенциальные арбитражные возможности между рынками одного токена';
