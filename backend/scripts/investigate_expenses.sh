#!/bin/bash

# Script to investigate expense data issues

ROOMSPACE_ID="3ce5eb29-004e-42ab-9034-5106e627a44a"

echo "=== Investigating Expenses for Roomspace $ROOMSPACE_ID ==="
echo ""

# Connect to database and run queries
docker exec roomease-postgres psql -U postgres -d roomease <<EOF

-- Show all expenses
SELECT id, title, amount, paid_by, split_type, created_at 
FROM expenses 
WHERE roomspace_id = '$ROOMSPACE_ID'
ORDER BY created_at;

-- Show all splits
SELECT es.id, es.expense_id, es.user_uid, es.amount, e.title, e.amount as expense_amount
FROM expense_splits es
JOIN expenses e ON e.id = es.expense_id
WHERE e.roomspace_id = '$ROOMSPACE_ID'
ORDER BY es.expense_id, es.user_uid;

-- Calculate balances manually
WITH expense_data AS (
  SELECT 
    paid_by as user_id,
    SUM(amount) as total_paid
  FROM expenses
  WHERE roomspace_id = '$ROOMSPACE_ID'
  GROUP BY paid_by
),
split_data AS (
  SELECT 
    es.user_uid as user_id,
    SUM(es.amount) as total_owed
  FROM expense_splits es
  JOIN expenses e ON e.id = es.expense_id
  WHERE e.roomspace_id = '$ROOMSPACE_ID'
  GROUP BY es.user_uid
)
SELECT 
  COALESCE(e.user_id, s.user_id) as user_id,
  COALESCE(e.total_paid, 0) as total_paid,
  COALESCE(s.total_owed, 0) as total_owed,
  COALESCE(e.total_paid, 0) - COALESCE(s.total_owed, 0) as balance
FROM expense_data e
FULL OUTER JOIN split_data s ON e.user_id = s.user_id
ORDER BY user_id;

-- Check if splits sum to expense amount
SELECT 
  e.id,
  e.title,
  e.amount as expense_amount,
  SUM(es.amount) as splits_sum,
  e.amount - SUM(es.amount) as difference
FROM expenses e
LEFT JOIN expense_splits es ON e.id = es.expense_id
WHERE e.roomspace_id = '$ROOMSPACE_ID'
GROUP BY e.id, e.title, e.amount
HAVING ABS(e.amount - COALESCE(SUM(es.amount), 0)) > 0.01;

EOF
