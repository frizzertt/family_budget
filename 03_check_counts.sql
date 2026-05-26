-- Контроль количества записей после заполнения.

SET search_path TO family_budget, public;

SELECT 'families' AS table_name, count(*) AS row_count FROM families
UNION ALL
SELECT 'family_members', count(*) FROM family_members
UNION ALL
SELECT 'product_types', count(*) FROM product_types
UNION ALL
SELECT 'products', count(*) FROM products
UNION ALL
SELECT 'accounts', count(*) FROM accounts
UNION ALL
SELECT 'income_transactions', count(*) FROM income_transactions
UNION ALL
SELECT 'purchase_payments', count(*) FROM purchase_payments
ORDER BY table_name;

