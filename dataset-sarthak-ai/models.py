from dataclasses import dataclass, field
from typing import Optional, List, Dict
from datetime import date, datetime
from config import Persona, GroupType, Category, Subcategory, LocationTier


@dataclass
class User:
    user_id: str
    name: str
    email: str
    age: int
    income: float
    persona: Persona
    location_tier: LocationTier
    join_date: date
    spending_multiplier: float
    category_weights: Dict[Category, float]
    subcategory_weights: Dict[Category, Dict[Subcategory, float]]
    activity_rate: float
    social_tendency: float
    consistency: float
    splurge_probability: float
    churn_periods: List[tuple]
    daily_lambda: float


@dataclass
class Group:
    group_id: str
    name: str
    group_type: GroupType
    created_date: date
    status: str
    default_split_method: str
    description: str


@dataclass
class GroupMembership:
    membership_id: str
    group_id: str
    user_id: str
    joined_date: date
    left_date: Optional[date]
    role: str
    share_percentage: float


@dataclass
class Expense:
    expense_id: str
    user_id: str
    group_id: Optional[str]
    date: date
    category: Category
    subcategory: Subcategory
    amount: float
    description: str
    is_group_expense: bool
    created_at: datetime
    is_recurring: bool = False
    recurrence_type: Optional[str] = None


@dataclass
class ExpenseSplit:
    split_id: str
    expense_id: str
    user_id: str
    amount: float
    percentage: float
    is_settled: bool = False


@dataclass
class Settlement:
    settlement_id: str
    from_user_id: str
    to_user_id: str
    group_id: str
    amount: float
    date: date
    status: str
    note: str