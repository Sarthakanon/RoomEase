"""ML model trainers for spending analytics."""

from .spending_predictor import SpendingPredictor, train_spending_predictor

__all__ = [
    'SpendingPredictor',
    'train_spending_predictor',
]
