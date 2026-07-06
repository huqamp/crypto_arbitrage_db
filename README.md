# Crypto Funding Arbitrage DB

Учебный PostgreSQL-проект для хранения данных о биржах, токенах, рынках, фандинг-ставках, ценах и потенциальных арбитражных возможностях.

## Структура

```text
crypto_arbitrage_db/
  README.md
  docker-compose.yml

  schemas/
    conceptual_model.png      -- концептуальная модель
    logical_model.png         -- логическая модель 
    physical_model.xlsx       -- физическая модель
  sql/
    01_schema.sql             -- создание таблиц, ограничений, индексов
    02_seed_data.sql          -- тестовые данные
    03_analytics_queries.sql  -- примеры аналитических запросов
    04_refresh_arbitrage.sql  -- расчёт и сохранение арбитражных возможностей
```

### Концептуальная модель

Файл: `schemas/conceptual_model.png`

Показывает основные сущности предметной области и связи между ними:

- `Exchange` — биржа;
- `Token` — криптоактив;
- `Market` — рынок конкретного токена на конкретной бирже;
- `FundingRate` — funding rate для рынка;
- `MarketPrice` — цена рынка;
- `ArbitrageOpportunity` — потенциальная арбитражная возможность между двумя рынками.

![Conceptual model](schemas/conceptual_model.png)

### Логическая модель

Файл: `schemas/logical_model.png`

Логическая модель уточняет связи между сущностями:

- `Exchange 1:N Market` — одна биржа может иметь много рынков;
- `Token 1:N Market` — один токен может торговаться на многих рынках;
- `Exchange M:N Token` — связь многие-ко-многим реализована через таблицу `Market`;
- `Market 1:N FundingRate` — для одного рынка может храниться история funding rate;
- `Market 1:1 MarketPrice` — для одного рынка хранится актуальная рыночная цена;
- `Market 1:N ArbitrageOpportunity` — один рынок может участвовать во многих арбитражных возможностях.

Таким образом, центральной сущностью является `Market`: она связывает биржу и токен, а также используется для хранения ставок funding rate, цены и расчёта арбитражных возможностей.

![Logical model](schemas/logical_model.png)

### Физическая модель

Файл: `schemas/physical_model.xlsx`

Содержит физическое описание таблиц: названия полей, ключи, типы данных и ограничения. 
## Как запустить

```bash
docker compose up -d
psql postgresql://postgres:postgres@localhost:5432/crypto_arbitrage -f sql/01_schema.sql
psql postgresql://postgres:postgres@localhost:5432/crypto_arbitrage -f sql/02_seed_data.sql
psql postgresql://postgres:postgres@localhost:5432/crypto_arbitrage -f sql/03_analytics_queries.sql
psql postgresql://postgres:postgres@localhost:5432/crypto_arbitrage -f sql/04_refresh_arbitrage.sql
```

## Главная аналитическая идея

Для одного и того же токена на разных биржах сравниваются:

- текущие funding rates;
- актуальные рыночные цены;
- разница цен;
- потенциальная доходность стратегии long/short между двумя площадками.

Например, если на одной бирже funding rate положительный, а на другой ниже или отрицательный, можно искать пару рынков, где выгодно держать противоположные позиции.
