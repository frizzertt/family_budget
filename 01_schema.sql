-- База данных "Семейный бюджет"
-- Скрипт создает отдельную схему family_budget и 7 связанных таблиц.

DROP SCHEMA IF EXISTS family_budget CASCADE;
CREATE SCHEMA family_budget;
SET search_path TO family_budget, public;

CREATE TABLE families (
    family_id bigserial PRIMARY KEY,
    family_name varchar(80) NOT NULL,
    city varchar(80) NOT NULL,
    address varchar(160) NOT NULL,
    registration_date date NOT NULL
);

CREATE TABLE family_members (
    member_id bigserial PRIMARY KEY,
    family_id bigint NOT NULL REFERENCES families(family_id) ON DELETE CASCADE,
    last_name varchar(60) NOT NULL,
    first_name varchar(60) NOT NULL,
    middle_name varchar(60),
    status varchar(30) NOT NULL,
    birth_date date NOT NULL,
    CONSTRAINT chk_family_members_status CHECK (
        status IN ('отец', 'мать', 'сын', 'дочь')
    ),
    CONSTRAINT chk_family_members_birth_date CHECK (birth_date <= CURRENT_DATE)
);

CREATE TABLE product_types (
    product_type_id bigserial PRIMARY KEY,
    type_name varchar(120) NOT NULL,
    expense_group varchar(80) NOT NULL,
    description varchar(240)
);

CREATE TABLE products (
    product_id bigserial PRIMARY KEY,
    product_type_id bigint NOT NULL REFERENCES product_types(product_type_id),
    product_name varchar(160) NOT NULL,
    unit_name varchar(20) NOT NULL,
    is_required boolean NOT NULL DEFAULT false
);

CREATE TABLE accounts (
    account_id bigserial PRIMARY KEY,
    member_id bigint NOT NULL REFERENCES family_members(member_id) ON DELETE CASCADE,
    account_name varchar(100) NOT NULL,
    account_type varchar(40) NOT NULL,
    currency_code char(3) NOT NULL DEFAULT 'RUB',
    opening_date date NOT NULL,
    initial_balance numeric(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT chk_accounts_type CHECK (
        account_type IN ('наличные', 'банковская карта', 'накопительный счет', 'электронный кошелек')
    ),
    CONSTRAINT chk_accounts_balance CHECK (initial_balance >= 0),
    CONSTRAINT uq_accounts_member_pair UNIQUE (account_id, member_id)
);

CREATE TABLE income_transactions (
    income_id bigserial PRIMARY KEY,
    member_id bigint NOT NULL,
    account_id bigint NOT NULL,
    income_date date NOT NULL,
    source_name varchar(100) NOT NULL,
    amount numeric(12,2) NOT NULL,
    comment varchar(200),
    CONSTRAINT fk_income_account_member FOREIGN KEY (account_id, member_id)
        REFERENCES accounts(account_id, member_id) ON DELETE CASCADE,
    CONSTRAINT chk_income_amount CHECK (amount > 0)
);

CREATE TABLE purchase_payments (
    payment_id bigserial PRIMARY KEY,
    member_id bigint NOT NULL,
    account_id bigint NOT NULL,
    product_id bigint NOT NULL REFERENCES products(product_id),
    purchase_date date NOT NULL,
    quantity numeric(10,2) NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    payment_method varchar(20) NOT NULL,
    comment varchar(200),
    CONSTRAINT fk_purchase_account_member FOREIGN KEY (account_id, member_id)
        REFERENCES accounts(account_id, member_id) ON DELETE CASCADE,
    CONSTRAINT chk_purchase_quantity CHECK (quantity > 0),
    CONSTRAINT chk_purchase_unit_price CHECK (unit_price >= 0),
    CONSTRAINT chk_purchase_total_amount CHECK (total_amount = round(quantity * unit_price, 2)),
    CONSTRAINT chk_purchase_method CHECK (payment_method IN ('карта', 'наличные', 'перевод'))
);

