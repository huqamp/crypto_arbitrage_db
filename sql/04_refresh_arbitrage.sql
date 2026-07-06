-- Сохраняем актуальные возможности в таблицу arbitrage_opportunity.
-- В реальном проекте это можно запускать по расписанию.

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
), opportunities AS (
    SELECT
        s1.market_id AS market1_id,
        s2.market_id AS market2_id,
        s1.rate_value AS funding_rate1,
        s2.rate_value AS funding_rate2,
        s1.price AS price1,
        s2.price AS price2,
        (s2.rate_value - s1.rate_value) AS funding_spread,
        ((s2.price - s1.price) / s1.price * 100) AS price_spread_pct,
        ((s2.rate_value - s1.rate_value) * 100) - ABS((s2.price - s1.price) / s1.price * 100) AS expected_profit_pct
    FROM market_state s1
    JOIN market_state s2
        ON s1.token = s2.token
       AND s1.market_id <> s2.market_id
    WHERE s2.rate_value > s1.rate_value
)
INSERT INTO arbitrage_opportunity (
    market1_id,
    market2_id,
    calculated_at,
    funding_rate1,
    funding_rate2,
    price1,
    price2,
    funding_spread,
    price_spread_pct,
    expected_profit_pct
)
SELECT
    market1_id,
    market2_id,
    now(),
    funding_rate1,
    funding_rate2,
    price1,
    price2,
    funding_spread,
    price_spread_pct,
    expected_profit_pct
FROM opportunities
WHERE expected_profit_pct > 0
ORDER BY expected_profit_pct DESC;

SELECT
    ao.arbitrage_id,
    t.symbol AS token,
    e1.code AS market1_exchange,
    e2.code AS market2_exchange,
    ao.funding_spread,
    ao.price_spread_pct,
    ao.expected_profit_pct,
    ao.calculated_at
FROM arbitrage_opportunity ao
JOIN market m1 ON m1.market_id = ao.market1_id
JOIN market m2 ON m2.market_id = ao.market2_id
JOIN token t ON t.token_id = m1.token_id
JOIN exchange e1 ON e1.exchange_id = m1.exchange_id
JOIN exchange e2 ON e2.exchange_id = m2.exchange_id
ORDER BY ao.expected_profit_pct DESC;
