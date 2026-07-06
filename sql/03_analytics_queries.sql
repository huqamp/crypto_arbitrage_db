-- 1. Список доступных рынков
SELECT
    e.code AS exchange,
    t.symbol AS token,
    m.symbol AS market_symbol,
    m.funding_interval
FROM market m
JOIN exchange e ON e.exchange_id = m.exchange_id
JOIN token t ON t.token_id = m.token_id
ORDER BY token, exchange;

-- 2. Текущие funding rates по рынкам
SELECT
    e.code AS exchange,
    t.symbol AS token,
    m.symbol AS market_symbol,
    fr.rate_value,
    fr.effective_from
FROM funding_rate fr
JOIN market m ON m.market_id = fr.market_id
JOIN exchange e ON e.exchange_id = m.exchange_id
JOIN token t ON t.token_id = m.token_id
WHERE fr.is_current = TRUE
ORDER BY token, fr.rate_value DESC;

-- 3. Последние цены по каждому рынку
WITH latest_price AS (
    SELECT
        mp.*,
        ROW_NUMBER() OVER (PARTITION BY market_id ORDER BY last_update DESC) AS rn
    FROM market_price mp
)
SELECT
    e.code AS exchange,
    t.symbol AS token,
    lp.price,
    lp.last_update
FROM latest_price lp
JOIN market m ON m.market_id = lp.market_id
JOIN exchange e ON e.exchange_id = m.exchange_id
JOIN token t ON t.token_id = m.token_id
WHERE lp.rn = 1
ORDER BY token, exchange;

-- 4. Лучшие пары для funding arbitrage:
-- market_long: где funding rate ниже;
-- market_short: где funding rate выше.
WITH current_rates AS (
    SELECT
        m.market_id,
        e.code AS exchange,
        t.symbol AS token,
        fr.rate_value
    FROM funding_rate fr
    JOIN market m ON m.market_id = fr.market_id
    JOIN exchange e ON e.exchange_id = m.exchange_id
    JOIN token t ON t.token_id = m.token_id
    WHERE fr.is_current = TRUE
)
SELECT
    r1.token,
    r1.exchange AS long_exchange,
    r2.exchange AS short_exchange,
    r1.rate_value AS long_funding_rate,
    r2.rate_value AS short_funding_rate,
    r2.rate_value - r1.rate_value AS funding_spread
FROM current_rates r1
JOIN current_rates r2
    ON r1.token = r2.token
   AND r1.market_id < r2.market_id
WHERE ABS(r2.rate_value - r1.rate_value) > 0.00005
ORDER BY funding_spread DESC;

-- 5. Расчёт ценового спреда между биржами для одного токена
WITH latest_price AS (
    SELECT
        mp.*,
        ROW_NUMBER() OVER (PARTITION BY market_id ORDER BY last_update DESC) AS rn
    FROM market_price mp
), prices AS (
    SELECT
        m.market_id,
        e.code AS exchange,
        t.symbol AS token,
        lp.price
    FROM latest_price lp
    JOIN market m ON m.market_id = lp.market_id
    JOIN exchange e ON e.exchange_id = m.exchange_id
    JOIN token t ON t.token_id = m.token_id
    WHERE lp.rn = 1
)
SELECT
    p1.token,
    p1.exchange AS exchange1,
    p2.exchange AS exchange2,
    p1.price AS price1,
    p2.price AS price2,
    ROUND(((p2.price - p1.price) / p1.price * 100), 6) AS price_spread_pct
FROM prices p1
JOIN prices p2
    ON p1.token = p2.token
   AND p1.market_id < p2.market_id
ORDER BY ABS((p2.price - p1.price) / p1.price) DESC;

-- 6. Топ потенциальных возможностей: funding spread + price spread
WITH latest_price AS (
    SELECT
        mp.*,
        ROW_NUMBER() OVER (PARTITION BY market_id ORDER BY last_update DESC) AS rn
    FROM market_price mp
), market_state AS (
    SELECT
        m.market_id,
        e.code AS exchange,
        t.symbol AS token,
        fr.rate_value,
        lp.price
    FROM market m
    JOIN exchange e ON e.exchange_id = m.exchange_id
    JOIN token t ON t.token_id = m.token_id
    JOIN funding_rate fr ON fr.market_id = m.market_id AND fr.is_current = TRUE
    JOIN latest_price lp ON lp.market_id = m.market_id AND lp.rn = 1
)
SELECT
    s1.token,
    s1.exchange AS market1_exchange,
    s2.exchange AS market2_exchange,
    s1.rate_value AS funding_rate1,
    s2.rate_value AS funding_rate2,
    s1.price AS price1,
    s2.price AS price2,
    ROUND((s2.rate_value - s1.rate_value), 6) AS funding_spread,
    ROUND(((s2.price - s1.price) / s1.price * 100), 6) AS price_spread_pct,
    ROUND(((s2.rate_value - s1.rate_value) * 100) - ABS((s2.price - s1.price) / s1.price * 100), 6) AS expected_profit_pct
FROM market_state s1
JOIN market_state s2
    ON s1.token = s2.token
   AND s1.market_id <> s2.market_id
WHERE s2.rate_value > s1.rate_value
ORDER BY expected_profit_pct DESC;
