-- Заполнение базы данных "Семейный бюджет".
-- Скрипт рассчитан на PostgreSQL и pgAdmin.
-- Основная сущность purchase_payments заполняется 1 000 000 записей.

SET search_path TO family_budget, public;

TRUNCATE TABLE
    purchase_payments,
    income_transactions,
    accounts,
    products,
    product_types,
    family_members,
    families
RESTART IDENTITY CASCADE;

INSERT INTO families (family_name, city, address, registration_date)
WITH source_data AS (
    SELECT ARRAY[
        'Москва', 'Санкт-Петербург', 'Казань', 'Нижний Новгород', 'Екатеринбург',
        'Новосибирск', 'Самара', 'Ростов-на-Дону', 'Воронеж', 'Пермь'
    ] AS cities
)
SELECT
    'Семья ' || gs AS family_name,
    cities[1 + ((gs - 1) % cardinality(cities))] AS city,
    'ул. Семейная, д. ' || (10 + gs) || ', кв. ' || (1 + (gs % 120)) AS address,
    DATE '2023-01-01' + (gs % 600) AS registration_date
FROM generate_series(1, 150) AS gs
CROSS JOIN source_data;

INSERT INTO family_members (
    family_id,
    last_name,
    first_name,
    middle_name,
    status,
    birth_date
)
WITH names AS (
    SELECT
        ARRAY['Иванов', 'Петров', 'Сидоров', 'Смирнов', 'Кузнецов', 'Попов', 'Васильев', 'Соколов'] AS last_names,
        ARRAY['Алексей', 'Дмитрий', 'Сергей', 'Михаил', 'Андрей', 'Николай', 'Павел', 'Илья'] AS father_names,
        ARRAY['Алексеевич', 'Дмитриевич', 'Сергеевич', 'Михайлович', 'Андреевич', 'Николаевич', 'Павлович', 'Ильич'] AS child_patronymics_male,
        ARRAY['Алексеевна', 'Дмитриевна', 'Сергеевна', 'Михайловна', 'Андреевна', 'Николаевна', 'Павловна', 'Ильинична'] AS child_patronymics_female,
        ARRAY['Иванович', 'Петрович', 'Викторович', 'Олегович'] AS adult_patronymics_male,
        ARRAY['Ивановна', 'Петровна', 'Викторовна', 'Олеговна'] AS adult_patronymics_female,
        ARRAY['Артем', 'Кирилл', 'Максим', 'Егор', 'Даниил', 'Роман'] AS son_names,
        ARRAY['Анна', 'Мария', 'Елена', 'Ольга', 'Алина', 'Виктория'] AS mother_names,
        ARRAY['Дарья', 'София', 'Полина', 'Екатерина', 'Ксения', 'Варвара'] AS daughter_names
)
SELECT
    f.family_id,
    CASE WHEN pos IN (2, 4)
        THEN last_names[1 + (((f.family_id - 1) % cardinality(last_names))::integer)] || 'а'
        ELSE last_names[1 + (((f.family_id - 1) % cardinality(last_names))::integer)]
    END AS last_name,
    CASE
        WHEN pos = 1 THEN father_names[1 + (((f.family_id - 1) % cardinality(father_names))::integer)]
        WHEN pos = 2 THEN mother_names[1 + (((f.family_id - 1) % cardinality(mother_names))::integer)]
        WHEN pos = 3 THEN son_names[1 + (((f.family_id - 1) % cardinality(son_names))::integer)]
        ELSE daughter_names[1 + (((f.family_id - 1) % cardinality(daughter_names))::integer)]
    END AS first_name,
    CASE
        WHEN pos = 1 THEN adult_patronymics_male[1 + (((f.family_id - 1) % cardinality(adult_patronymics_male))::integer)]
        WHEN pos = 2 THEN adult_patronymics_female[1 + (((f.family_id + 1) % cardinality(adult_patronymics_female))::integer)]
        WHEN pos = 3 THEN child_patronymics_male[1 + (((f.family_id - 1) % cardinality(father_names))::integer)]
        ELSE child_patronymics_female[1 + (((f.family_id - 1) % cardinality(father_names))::integer)]
    END AS middle_name,
    CASE pos
        WHEN 1 THEN 'отец'
        WHEN 2 THEN 'мать'
        WHEN 3 THEN 'сын'
        ELSE 'дочь'
    END AS status,
    CASE pos
        WHEN 1 THEN DATE '1975-01-01' + (((f.family_id * 17) % 5000)::integer)
        WHEN 2 THEN DATE '1977-01-01' + (((f.family_id * 19) % 5000)::integer)
        WHEN 3 THEN DATE '2007-01-01' + (((f.family_id * 23) % 4500)::integer)
        ELSE DATE '2009-01-01' + (((f.family_id * 29) % 4500)::integer)
    END AS birth_date
FROM families AS f
CROSS JOIN generate_series(1, 4) AS pos
CROSS JOIN names
ORDER BY f.family_id, pos;

INSERT INTO product_types (type_name, expense_group, description)
WITH groups AS (
    SELECT ARRAY[
        'продукты питания',
        'транспорт',
        'коммунальные услуги',
        'одежда',
        'здоровье',
        'образование',
        'связь',
        'досуг',
        'товары для дома',
        'прочие расходы'
    ] AS expense_groups
)
SELECT
    expense_groups[1 + ((gs - 1) % cardinality(expense_groups))]
        || ' ' || (1 + ((gs - 1) / cardinality(expense_groups))) AS type_name,
    expense_groups[1 + ((gs - 1) % cardinality(expense_groups))] AS expense_group,
    'Категория расходов семейного бюджета' AS description
FROM generate_series(1, 120) AS gs
CROSS JOIN groups;

INSERT INTO products (product_type_id, product_name, unit_name, is_required)
SELECT
    pt.product_type_id,
    pt.type_name || ', товар ' || product_no AS product_name,
    CASE
        WHEN pt.expense_group = 'продукты питания' THEN 'кг'
        WHEN pt.expense_group IN ('коммунальные услуги', 'связь') THEN 'мес.'
        ELSE 'шт.'
    END AS unit_name,
    pt.expense_group IN ('продукты питания', 'коммунальные услуги', 'здоровье') AS is_required
FROM product_types AS pt
CROSS JOIN generate_series(1, 20) AS product_no
ORDER BY pt.product_type_id, product_no;

INSERT INTO accounts (
    member_id,
    account_name,
    account_type,
    currency_code,
    opening_date,
    initial_balance
)
SELECT
    member_id,
    'Основной счет ' || member_id AS account_name,
    CASE member_id % 4
        WHEN 0 THEN 'наличные'
        WHEN 1 THEN 'банковская карта'
        WHEN 2 THEN 'накопительный счет'
        ELSE 'электронный кошелек'
    END AS account_type,
    'RUB' AS currency_code,
    DATE '2023-01-01' + ((member_id % 500)::integer) AS opening_date,
    (1000 + (member_id % 50) * 100)::numeric(12,2) AS initial_balance
FROM family_members
ORDER BY member_id;

INSERT INTO income_transactions (
    member_id,
    account_id,
    income_date,
    source_name,
    amount,
    comment
)
SELECT
    fm.member_id,
    a.account_id,
    (DATE '2024-01-05' + (month_no * INTERVAL '1 month'))::date AS income_date,
    CASE
        WHEN fm.status IN ('отец', 'мать') THEN 'заработная плата'
        ELSE 'карманные средства'
    END AS source_name,
    CASE
        WHEN fm.status = 'отец' THEN (65000 + (fm.member_id % 30) * 1200 + month_no * 150)::numeric(12,2)
        WHEN fm.status = 'мать' THEN (57000 + (fm.member_id % 25) * 1100 + month_no * 130)::numeric(12,2)
        WHEN fm.status = 'сын' THEN (6000 + (fm.member_id % 12) * 250)::numeric(12,2)
        ELSE (5500 + (fm.member_id % 12) * 220)::numeric(12,2)
    END AS amount,
    'Сгенерированная запись о доходе' AS comment
FROM family_members AS fm
JOIN accounts AS a ON a.member_id = fm.member_id
CROSS JOIN generate_series(0, 27) AS month_no
ORDER BY fm.member_id, month_no;

CREATE TEMP TABLE tmp_members AS
SELECT
    row_number() OVER (ORDER BY member_id) AS rn,
    member_id
FROM family_members;

CREATE TEMP TABLE tmp_products AS
SELECT
    row_number() OVER (ORDER BY product_id) AS rn,
    product_id
FROM products;

CREATE INDEX tmp_members_rn_idx ON tmp_members(rn);
CREATE INDEX tmp_products_rn_idx ON tmp_products(rn);

INSERT INTO purchase_payments (
    member_id,
    account_id,
    product_id,
    purchase_date,
    quantity,
    unit_price,
    total_amount,
    payment_method,
    comment
)
WITH counts AS (
    SELECT
        (SELECT count(*) FROM tmp_members)::integer AS member_count,
        (SELECT count(*) FROM tmp_products)::integer AS product_count
)
SELECT
    tm.member_id,
    a.account_id,
    tp.product_id,
    DATE '2024-01-01' + ((gs * 13) % 880) AS purchase_date,
    v.quantity,
    v.unit_price,
    round(v.quantity * v.unit_price, 2) AS total_amount,
    CASE gs % 3
        WHEN 0 THEN 'карта'
        WHEN 1 THEN 'наличные'
        ELSE 'перевод'
    END AS payment_method,
    'Сгенерированный платеж по покупке' AS comment
FROM generate_series(1, 1000000) AS gs
CROSS JOIN counts
JOIN tmp_members AS tm
    ON tm.rn = 1 + ((gs * 37) % counts.member_count)
JOIN accounts AS a
    ON a.member_id = tm.member_id
JOIN tmp_products AS tp
    ON tp.rn = 1 + (((gs * 53 + (gs / counts.member_count) * 97) % counts.product_count)::integer)
CROSS JOIN LATERAL (
    SELECT
        (1 + ((gs * 7) % 5))::numeric(10,2) AS quantity,
        (30 + ((gs * 17) % 5000) + (tp.product_id % 200))::numeric(12,2) AS unit_price
) AS v;

CREATE INDEX idx_family_members_family ON family_members(family_id);
CREATE INDEX idx_products_type ON products(product_type_id);
CREATE INDEX idx_accounts_member ON accounts(member_id);
CREATE INDEX idx_income_member_date ON income_transactions(member_id, income_date);
CREATE INDEX idx_purchase_member_date ON purchase_payments(member_id, purchase_date);
CREATE INDEX idx_purchase_product_date ON purchase_payments(product_id, purchase_date);
CREATE INDEX idx_purchase_account ON purchase_payments(account_id);

ANALYZE;
