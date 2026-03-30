#!/bin/bash

# Balance Debug Script
# Usage: ./debug_balance_detailed.sh <roomspace_id>

ROOMSPACE_ID=$1

if [ -z "$ROOMSPACE_ID" ]; then
    echo "Usage: ./debug_balance_detailed.sh <roomspace_id>"
    exit 1
fi

echo "==================================="
echo "Balance Debug Report"
echo "Roomspace ID: $ROOMSPACE_ID"
echo "==================================="
echo ""

# Connect to PostgreSQL and run debug queries
PGPASSWORD=postgres psql -h localhost -U postgres -d roomease << EOF

-- 1. User Balances Summary
\echo '1. USER BALANCES SUMMARY'
\echo '========================'
SELECT 
    rm.user_id,
    u.name,
    COALESCE(SUM(CASE WHEN e.paid_by = rm.user_id THEN e.amount ELSE 0 END), 0) as total_paid,
    COALESCE(SUM(es.amount), 0) as total_owed,
    COALESCE(SUM(CASE WHEN e.paid_by = rm.user_id THEN e.amount ELSE 0 END), 0) - COALESCE(SUM(es.amount), 0) as balance
FROM roomspace_members rm
LEFT JOIN users u ON u.firebase_uid = rm.user_id
LEFT JOIN expenses e ON e.roomspace_id = rm.roomspace_id AND e.paid_by = rm.user_id
LEFT JOIN expense_splits es ON es.user_uid = rm.user_id 
    AND es.expense_id IN (SELECT id FROM expenses WHERE roomspace_id = rm.roomspace_id)
WHERE rm.roomspace_id = '$ROOMSPACE_ID'
    AND rm.is_active = true
GROUP BY rm.user_id, u.name
ORDER BY balance DESC;

\echo ''
\echo '2. BALANCE CHECK (Should sum to ~0)'
\echo '===================================='
SELECT 
    SUM(balance) as total_balance_sum
FROM (
    SELECT 
        COALESCE(SUM(CASE WHEN e.paid_by = rm.user_id THEN e.amount ELSE 0 END), 0) - COALESCE(SUM(es.amount), 0) as balance
    FROM roomspace_members rm
    LEFT JOIN expenses e ON e.roomspace_id = rm.roomspace_id AND e.paid_by = rm.user_id
    LEFT JOIN expense_splits es ON es.user_uid = rm.user_id 
        AND es.expense_id IN (SELECT id FROM expenses WHERE roomspace_id = rm.roomspace_id)
    WHERE rm.roomspace_id = '$ROOMSPACE_ID'
        AND rm.is_active = true
    GROUP BY rm.user_id
) as balances;

\echo ''
\echo '3. DUPLICATE SPLITS CHECK'
\echo '========================='
SELECT 
    e.id,
    e.title,
    e.amount,
    es.user_uid,
    u.name,
    COUNT(*) as duplicate_count,
    SUM(es.amount) as total_amount
FROM expenses e
JOIN expense_splits es ON es.expense_id = e.id
LEFT JOIN users u ON u.firebase_uid = es.user_uid
WHERE e.roomspace_id = '$ROOMSPACE_ID'
GROUP BY e.id, e.title, e.amount, es.user_uid, u.name
HAVING COUNT(*) > 1
ORDER BY e.id, es.user_uid;

\echo ''
\echo '4. SPLIT AMOUNT MISMATCH CHECK'
\echo '=============================='
SELECT 
    e.id,
    e.title,
    e.amount as expense_amount,
    COALESCE(SUM(es.amount), 0) as total_splits,
    e.amount - COALESCE(SUM(es.amount), 0) as difference
FROM expenses e
LEFT JOIN expense_splits es ON es.expense_id = e.id
WHERE e.roomspace_id = '$ROOMSPACE_ID'
GROUP BY e.id, e.title, e.amount
HAVING ABS(e.amount - COALESCE(SUM(es.amount), 0)) > 0.01
ORDER BY ABS(e.amount - COALESCE(SUM(es.amount), 0)) DESC;

\echo ''
\echo '5. EXPENSES WITHOUT SPLITS'
\echo '=========================='
SELECT 
    e.id,
    e.title,
    e.amount,
    e.paid_by,
    u.name as payer_name,
    COUNT(es.id) as split_count
FROM expenses e
LEFT JOIN users u ON u.firebase_uid = e.paid_by
LEFT JOIN expense_splits es ON es.expense_id = e.id
WHERE e.roomspace_id = '$ROOMSPACE_ID'
GROUP BY e.id, e.title, e.amount, e.paid_by, u.name
HAVING COUNT(es.id) = 0;

\echo ''
\echo '6. RECENT EXPENSES (Last 10)'
\echo '============================'
SELECT 
    e.id,
    e.title,
    e.amount,
    u.name as paid_by,
    e.created_at,
    COUNT(es.id) as split_count,
    SUM(es.amount) as total_split
FROM expenses e
LEFT JOIN users u ON u.firebase_uid = e.paid_by
LEFT JOIN expense_splits es ON es.expense_id = e.id
WHERE e.roomspace_id = '$ROOMSPACE_ID'
GROUP BY e.id, e.title, e.amount, u.name, e.created_at
ORDER BY e.created_at DESC
LIMIT 10;

EOF

echo ""
echo "==================================="
echo "Debug report complete!"
echo "==================================="
