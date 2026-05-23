import numpy as np
import pandas as pd
from datetime import date, timedelta
from typing import List, Dict, Tuple
from collections import defaultdict
from config import GenerationConfig, GROUP_TYPE_PARAMS, GroupType
from models import Expense, ExpenseSplit, Settlement, Group


def simplify_debts(balances: Dict[str, float]) -> List[Tuple[str, str, float]]:
    creditors = [(uid, amt) for uid, amt in balances.items() if amt > 0.5]
    debtors = [(uid, -amt) for uid, amt in balances.items() if amt < -0.5]
    creditors.sort(key=lambda x: -x[1])
    debtors.sort(key=lambda x: -x[1])

    transactions = []
    i, j = 0, 0
    while i < len(creditors) and j < len(debtors):
        creditor_id, credit = creditors[i]
        debtor_id, debt = debtors[j]
        amount = min(credit, debt)
        if amount > 0.5:
            transactions.append((debtor_id, creditor_id, round(amount, 2)))
        creditors[i] = (creditor_id, credit - amount)
        debtors[j] = (debtor_id, debt - amount)
        if creditors[i][1] < 0.5:
            i += 1
        if debtors[j][1] < 0.5:
            j += 1
    return transactions


def generate_settlements(
    config: GenerationConfig,
    groups: List[Group],
    expenses: List[Expense],
    splits: List[ExpenseSplit],
) -> List[Settlement]:
    rng = np.random.default_rng(config.seed + 30000)
    end_date = date.fromisoformat(config.end_date)

    print("  Building indexes...")
    expense_by_group: Dict[str, List[Expense]] = defaultdict(list)
    for e in expenses:
        if e.is_group_expense and e.group_id:
            expense_by_group[e.group_id].append(e)

    split_by_expense: Dict[str, List[ExpenseSplit]] = defaultdict(list)
    for s in splits:
        split_by_expense[s.expense_id].append(s)

    for gid in expense_by_group:
        expense_by_group[gid].sort(key=lambda e: e.date)

    settlement_frequency = {
        GroupType.HOUSEHOLD: 1, GroupType.FRIENDS: 2,
        GroupType.OFFICE: 1, GroupType.TRAVEL: 0,
        GroupType.FAMILY: 1, GroupType.PROJECT: 2,
    }

    settlements = []
    settlement_id = 0

    for group in groups:
        group_id = group.group_id
        freq = settlement_frequency.get(group.group_type, 1)
        group_expenses = expense_by_group.get(group_id, [])

        if not group_expenses:
            continue

        settle_day = 1 if group.group_type == GroupType.HOUSEHOLD else 15
        current = group.created_date
        try:
            current = current.replace(day=settle_day)
        except ValueError:
            current = current.replace(day=28)

        if current < group.created_date:
            if current.month == 12:
                current = date(current.year + 1, 1, settle_day)
            else:
                current = date(current.year, current.month + 1, settle_day)

        current = current + timedelta(days=30 * freq) if freq > 0 else current + timedelta(days=7)

        balance = defaultdict(float)
        eidx = 0

        while current <= end_date:
            while eidx < len(group_expenses) and group_expenses[eidx].date <= current:
                e = group_expenses[eidx]
                for s in split_by_expense.get(e.expense_id, []):
                    if not s.is_settled:
                        if s.user_id == e.user_id:
                            balance[s.user_id] += e.amount - s.amount
                        else:
                            balance[s.user_id] -= s.amount
                eidx += 1

            transactions = simplify_debts(dict(balance))
            for from_id, to_id, amount in transactions:
                if amount < 1.0:
                    continue
                status = "completed" if rng.random() < 0.85 else ("pending" if rng.random() < 0.7 else "rejected")
                note_options = [
                    f"Monthly settlement for {group.name}",
                    f"Clearing balance - {current.strftime('%B %Y')}",
                    f"Payment for shared expenses",
                    f"Settlement for {group.group_type.value} expenses",
                ]
                settlement = Settlement(
                    settlement_id=f"STL_{settlement_id+1:08d}",
                    from_user_id=from_id, to_user_id=to_id,
                    group_id=group_id, amount=amount, date=current,
                    status=status, note=str(rng.choice(note_options)),
                )
                settlements.append(settlement)
                settlement_id += 1

            if freq > 0:
                current = current + timedelta(days=30 * freq)
            else:
                current = current + timedelta(days=7)

    print(f"  Generated {settlement_id} settlements")
    return settlements


def settlements_to_dataframe(settlements: List[Settlement]) -> pd.DataFrame:
    rows = []
    for s in settlements:
        rows.append({
            "settlement_id": s.settlement_id,
            "from_user_id": s.from_user_id,
            "to_user_id": s.to_user_id,
            "group_id": s.group_id,
            "amount": s.amount,
            "date": s.date.isoformat(),
            "status": s.status,
            "note": s.note,
        })
    return pd.DataFrame(rows)