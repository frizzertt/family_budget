-- Сложные запросы к базе данных "Семейный бюджет".

SET search_path TO family_budget, public;

-- 1. Доходы, расходы и остаток семьи по месяцам.
WITH monthly_income AS (
    SELECT
        fm.family_id,
        date_trunc('month', it.income_date)::date AS month_start,
        sum(it.amount) AS income_amount
    FROM income_transactions AS it
    JOIN family_members AS fm ON fm.member_id = it.member_id
    GROUP BY fm.family_id, date_trunc('month', it.income_date)
),
monthly_expense AS (
    SELECT
        fm.family_id,
        date_trunc('month', pp.purchase_date)::date AS month_start,
        sum(pp.total_amount) AS expense_amount
    FROM purchase_payments AS pp
    JOIN family_members AS fm ON fm.member_id = pp.member_id
    GROUP BY fm.family_id, date_trunc('month', pp.purchase_date)
)
SELECT
    f.family_id,
    f.family_name,
    COALESCE(mi.month_start, me.month_start) AS month_start,
    COALESCE(mi.income_amount, 0) AS income_amount,
    COALESCE(me.expense_amount, 0) AS expense_amount,
    COALESCE(mi.income_amount, 0) - COALESCE(me.expense_amount, 0) AS balance_amount
FROM families AS f
LEFT JOIN monthly_income AS mi ON mi.family_id = f.family_id
LEFT JOIN monthly_expense AS me
    ON me.family_id = f.family_id
    AND me.month_start = mi.month_start
WHERE f.family_id = 1
ORDER BY month_start;

-- 2. Структура расходов семьи по группам расходов за выбранный год.
WITH expenses_by_group AS (
    SELECT
        fm.family_id,
        pt.expense_group,
        sum(pp.total_amount) AS group_amount
    FROM purchase_payments AS pp
    JOIN family_members AS fm ON fm.member_id = pp.member_id
    JOIN products AS p ON p.product_id = pp.product_id
    JOIN product_types AS pt ON pt.product_type_id = p.product_type_id
    WHERE pp.purchase_date >= DATE '2025-01-01'
      AND pp.purchase_date < DATE '2026-01-01'
      AND fm.family_id = 1
    GROUP BY fm.family_id, pt.expense_group
)
SELECT
    expense_group,
    group_amount,
    round(group_amount * 100 / sum(group_amount) OVER (), 2) AS percent_of_total
FROM expenses_by_group
ORDER BY group_amount DESC;

-- 3. Расходы членов семьи с ранжированием внутри семьи.
WITH member_expenses AS (
    SELECT
        fm.family_id,
        fm.member_id,
        fm.last_name || ' ' || fm.first_name AS member_name,
        fm.status,
        sum(pp.total_amount) AS expense_amount
    FROM family_members AS fm
    JOIN purchase_payments AS pp ON pp.member_id = fm.member_id
    WHERE fm.family_id = 1
      AND pp.purchase_date >= DATE '2025-01-01'
      AND pp.purchase_date < DATE '2026-01-01'
    GROUP BY fm.family_id, fm.member_id, fm.last_name, fm.first_name, fm.status
)
SELECT
    member_name,
    status,
    expense_amount,
    dense_rank() OVER (ORDER BY expense_amount DESC) AS expense_rank
FROM member_expenses
ORDER BY expense_rank, member_name;

-- 4. Товары с наибольшим ростом средней цены между 2024 и 2025 годами.
WITH avg_prices AS (
    SELECT
        p.product_id,
        p.product_name,
        EXTRACT(YEAR FROM pp.purchase_date)::integer AS purchase_year,
        avg(pp.unit_price) AS avg_price
    FROM purchase_payments AS pp
    JOIN products AS p ON p.product_id = pp.product_id
    WHERE pp.purchase_date >= DATE '2024-01-01'
      AND pp.purchase_date < DATE '2026-01-01'
    GROUP BY p.product_id, p.product_name, EXTRACT(YEAR FROM pp.purchase_date)
),
price_compare AS (
    SELECT
        product_id,
        product_name,
        max(avg_price) FILTER (WHERE purchase_year = 2024) AS avg_price_2024,
        max(avg_price) FILTER (WHERE purchase_year = 2025) AS avg_price_2025
    FROM avg_prices
    GROUP BY product_id, product_name
)
SELECT
    product_name,
    round(avg_price_2024, 2) AS avg_price_2024,
    round(avg_price_2025, 2) AS avg_price_2025,
    round((avg_price_2025 - avg_price_2024) * 100 / NULLIF(avg_price_2024, 0), 2) AS growth_percent
FROM price_compare
WHERE avg_price_2024 IS NOT NULL
  AND avg_price_2025 IS NOT NULL
ORDER BY growth_percent DESC
LIMIT 20;

-- 5. Остаток по счетам: начальный остаток + доходы - расходы.
WITH income_by_account AS (
    SELECT account_id, sum(amount) AS income_amount
    FROM income_transactions
    GROUP BY account_id
),
expense_by_account AS (
    SELECT account_id, sum(total_amount) AS expense_amount
    FROM purchase_payments
    GROUP BY account_id
)
SELECT
    f.family_name,
    fm.last_name || ' ' || fm.first_name AS member_name,
    a.account_name,
    a.account_type,
    a.initial_balance,
    COALESCE(iba.income_amount, 0) AS income_amount,
    COALESCE(eba.expense_amount, 0) AS expense_amount,
    a.initial_balance + COALESCE(iba.income_amount, 0) - COALESCE(eba.expense_amount, 0) AS calculated_balance
FROM accounts AS a
JOIN family_members AS fm ON fm.member_id = a.member_id
JOIN families AS f ON f.family_id = fm.family_id
LEFT JOIN income_by_account AS iba ON iba.account_id = a.account_id
LEFT JOIN expense_by_account AS eba ON eba.account_id = a.account_id
WHERE f.family_id = 1
ORDER BY calculated_balance;

-- 6. Семьи, у которых расходы превышали доходы минимум в двух месяцах.
WITH monthly_income AS (
    SELECT
        fm.family_id,
        date_trunc('month', it.income_date)::date AS month_start,
        sum(it.amount) AS income_amount
    FROM income_transactions AS it
    JOIN family_members AS fm ON fm.member_id = it.member_id
    GROUP BY fm.family_id, date_trunc('month', it.income_date)
),
monthly_expense AS (
    SELECT
        fm.family_id,
        date_trunc('month', pp.purchase_date)::date AS month_start,
        sum(pp.total_amount) AS expense_amount
    FROM purchase_payments AS pp
    JOIN family_members AS fm ON fm.member_id = pp.member_id
    GROUP BY fm.family_id, date_trunc('month', pp.purchase_date)
),
monthly_balance AS (
    SELECT
        mi.family_id,
        mi.month_start,
        mi.income_amount,
        COALESCE(me.expense_amount, 0) AS expense_amount
    FROM monthly_income AS mi
    LEFT JOIN monthly_expense AS me
        ON me.family_id = mi.family_id
        AND me.month_start = mi.month_start
)
SELECT
    f.family_id,
    f.family_name,
    count(*) AS deficit_month_count,
    sum(expense_amount - income_amount) AS total_deficit
FROM monthly_balance AS mb
JOIN families AS f ON f.family_id = mb.family_id
WHERE expense_amount > income_amount
GROUP BY f.family_id, f.family_name
HAVING count(*) >= 2
ORDER BY total_deficit DESC;

-- 7. Параметризуемый запрос по условию преподавателя.
-- В CTE params можно менять семью, период, группу расходов и минимальную сумму покупки.
WITH params AS (
    SELECT
        1::bigint AS selected_family_id,
        DATE '2025-01-01' AS date_from,
        DATE '2025-12-31' AS date_to,
        'образование%'::text AS type_name_mask,
        1000::numeric AS min_payment_amount
)
SELECT
    f.family_name,
    fm.last_name || ' ' || fm.first_name AS member_name,
    pt.type_name,
    p.product_name,
    pp.purchase_date,
    pp.quantity,
    pp.unit_price,
    pp.total_amount
FROM purchase_payments AS pp
JOIN family_members AS fm ON fm.member_id = pp.member_id
JOIN families AS f ON f.family_id = fm.family_id
JOIN products AS p ON p.product_id = pp.product_id
JOIN product_types AS pt ON pt.product_type_id = p.product_type_id
CROSS JOIN params
WHERE f.family_id = params.selected_family_id
  AND pp.purchase_date BETWEEN params.date_from AND params.date_to
  AND pt.type_name ILIKE params.type_name_mask
  AND pp.total_amount >= params.min_payment_amount
ORDER BY pp.total_amount DESC, pp.purchase_date
LIMIT 100;
