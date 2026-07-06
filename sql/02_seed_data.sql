INSERT INTO exchange (name, code, api_url) VALUES
    ('Binance', 'BINANCE', 'https://api.binance.com'),
    ('Bybit', 'BYBIT', 'https://api.bybit.com'),
    ('OKX', 'OKX', 'https://www.okx.com/api'),
    ('Gate.io', 'GATE', 'https://api.gateio.ws')
ON CONFLICT DO NOTHING;

INSERT INTO token (symbol, name, asset_type) VALUES
    ('BTC', 'Bitcoin', 'coin'),
    ('ETH', 'Ethereum', 'coin'),
    ('SOL', 'Solana', 'coin'),
    ('XRP', 'Ripple', 'coin')
ON CONFLICT DO NOTHING;

INSERT INTO market (exchange_id, token_id, symbol, funding_interval)
SELECT e.exchange_id, t.token_id, t.symbol || 'USDT', 8
FROM exchange e
CROSS JOIN token t
WHERE e.code IN ('BINANCE', 'BYBIT', 'OKX')
ON CONFLICT DO NOTHING;

-- Исторические и текущие funding rates.
INSERT INTO funding_rate (market_id, rate_value, effective_from, effective_to, is_current)
SELECT m.market_id, v.rate_value, v.effective_from, v.effective_to, v.is_current
FROM market m
JOIN exchange e ON e.exchange_id = m.exchange_id
JOIN token t ON t.token_id = m.token_id
JOIN (
    VALUES
    ('BINANCE', 'BTC',  0.000120::NUMERIC, now() - INTERVAL '16 hours', now() - INTERVAL '8 hours', FALSE),
    ('BINANCE', 'BTC',  0.000180::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),
    ('BYBIT',   'BTC', -0.000050::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),
    ('OKX',     'BTC',  0.000020::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),

    ('BINANCE', 'ETH',  0.000090::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),
    ('BYBIT',   'ETH',  0.000210::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),
    ('OKX',     'ETH', -0.000030::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),

    ('BINANCE', 'SOL', -0.000110::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),
    ('BYBIT',   'SOL',  0.000070::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),
    ('OKX',     'SOL',  0.000160::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),

    ('BINANCE', 'XRP',  0.000030::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),
    ('BYBIT',   'XRP',  0.000080::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE),
    ('OKX',     'XRP', -0.000020::NUMERIC, now() - INTERVAL '8 hours', NULL, TRUE)
) AS v(exchange_code, token_symbol, rate_value, effective_from, effective_to, is_current)
    ON v.exchange_code = e.code AND v.token_symbol = t.symbol
ON CONFLICT DO NOTHING;

-- Последние рыночные цены.
INSERT INTO market_price (market_id, price, last_update)
SELECT m.market_id, v.price, now() - v.delay
FROM market m
JOIN exchange e ON e.exchange_id = m.exchange_id
JOIN token t ON t.token_id = m.token_id
JOIN (
    VALUES
    ('BINANCE', 'BTC', 65400.10::NUMERIC, INTERVAL '2 minutes'),
    ('BYBIT',   'BTC', 65365.80::NUMERIC, INTERVAL '3 minutes'),
    ('OKX',     'BTC', 65420.35::NUMERIC, INTERVAL '1 minutes'),

    ('BINANCE', 'ETH', 3420.50::NUMERIC, INTERVAL '2 minutes'),
    ('BYBIT',   'ETH', 3416.20::NUMERIC, INTERVAL '4 minutes'),
    ('OKX',     'ETH', 3425.10::NUMERIC, INTERVAL '1 minutes'),

    ('BINANCE', 'SOL', 151.30::NUMERIC, INTERVAL '2 minutes'),
    ('BYBIT',   'SOL', 150.80::NUMERIC, INTERVAL '3 minutes'),
    ('OKX',     'SOL', 151.90::NUMERIC, INTERVAL '1 minutes'),

    ('BINANCE', 'XRP', 0.6120::NUMERIC, INTERVAL '2 minutes'),
    ('BYBIT',   'XRP', 0.6112::NUMERIC, INTERVAL '3 minutes'),
    ('OKX',     'XRP', 0.6131::NUMERIC, INTERVAL '1 minutes')
) AS v(exchange_code, token_symbol, price, delay)
    ON v.exchange_code = e.code AND v.token_symbol = t.symbol
ON CONFLICT DO NOTHING;
