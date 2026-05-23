"""
04_insight_engine.py
The assistant-facing insight engine that combines all three models
to provide actionable spending recommendations.

This module serves as the API layer between the trained models and
the application's assistant interface. It provides:
  - Individual spending insights
  - Group spending analysis
  - Overspending alerts
  - Category-level recommendations
  - Predictive spending forecasts
"""
import pandas as pd
import numpy as np
import json
import joblib
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional

MODELS_DIR = Path("../models")
FEATURES_DIR = Path("../features")
OUTPUT_DIR = Path("../output")

CATEGORIES = [
    'food_dining', 'transportation', 'housing', 'entertainment',
    'shopping', 'health', 'travel', 'education', 'subscriptions', 'gifts_donations'
]

CATEGORY_SUGGESTIONS = {
    'food_dining': {
        'reduce': [
            "Try meal prepping to reduce dining out expenses by 20-30%",
            "Set a weekly grocery budget and stick to it",
            "Reduce delivery orders - cooking at home saves 40-60%",
            "Look for lunch deals near your office/workplace",
        ],
        'optimize': [
            "Consider switching to a cashback credit card for dining",
            "Buy groceries in bulk on weekends for better deals",
            "Use restaurant loyalty programs for discounts",
        ],
    },
    'transportation': {
        'reduce': [
            "Consider public transit passes for daily commuting",
            "Carpool to reduce fuel costs by 50%",
            "Walk or bike for trips under 2 miles",
        ],
        'optimize': [
            "Compare ride-share prices before booking",
            "Refuel at stations with loyalty programs",
            "Consider a more fuel-efficient vehicle",
        ],
    },
    'housing': {
        'reduce': [
            "Review utility bills for potential savings (LED bulbs, smart thermostat)",
            "Negotiate rent at renewal time",
            "Consider refinancing if interest rates have dropped",
        ],
        'optimize': [
            "Set up autopay for on-time payment discounts",
            "Review insurance premiums annually",
            "Energy efficiency upgrades can save 10-20% on utilities",
        ],
    },
    'entertainment': {
        'reduce': [
            "Audit subscriptions - cancel ones you haven't used in 30 days",
            "Look for free local events and activities",
            "Set a monthly entertainment budget and track it",
        ],
        'optimize': [
            "Share streaming subscriptions with family members",
            "Use free trials strategically before committing",
            "Look for early-bird or matinee pricing",
        ],
    },
    'shopping': {
        'reduce': [
            "Apply the 48-hour rule before non-essential purchases",
            "Unsubscribe from promotional emails to reduce impulse buying",
            "Try a 'no-spend' weekend challenge once a month",
        ],
        'optimize': [
            "Use price comparison tools before major purchases",
            "Wait for seasonal sales for clothing and electronics",
            "Buy generic brands where quality is comparable",
        ],
    },
    'health': {
        'reduce': [
            "Use preventive care to avoid expensive treatments",
            "Check if your employer offers wellness program discounts",
            "Compare pharmacy prices - they vary significantly",
        ],
        'optimize': [
            "Maximize your health insurance benefits",
            "Consider telehealth for non-emergency consultations",
        ],
    },
    'travel': {
        'reduce': [
            "Book flights 4-8 weeks in advance for best prices",
            "Consider off-season travel for 30-50% savings",
            "Set price alerts for destinations you're interested in",
        ],
        'optimize': [
            "Use travel credit cards for points and perks",
            "Consider vacation rentals over hotels for longer stays",
            "Look for package deals that bundle flights and hotels",
        ],
    },
    'education': {
        'reduce': [
            "Explore free online courses before paying for premium ones",
            "Check for employer tuition reimbursement programs",
            "Use library resources for books and learning materials",
        ],
        'optimize': [
            "Invest in skills that directly increase earning potential",
            "Group purchases with classmates for discounts",
        ],
    },
    'subscriptions': {
        'reduce': [
            "Audit all subscriptions quarterly - cancel unused ones",
            "Downgrade premium plans to basic where sufficient",
            "Share family plans where possible",
        ],
        'optimize': [
            "Pay annually instead of monthly for 15-20% savings",
            "Bundle services when available for better rates",
        ],
    },
    'gifts_donations': {
        'reduce': [
            "Set an annual gifting budget to avoid overspending",
            "Make handmade gifts for close family and friends",
            "Consolidate charitable donations for tax benefits",
        ],
        'optimize': [
            "Plan gift purchases during sales events",
            "Track birthdays and plan purchases in advance",
        ],
    },
}


class ExpenseInsightEngine:
    def __init__(self):
        print("Loading models and data...")
        self.regressor = joblib.load(MODELS_DIR / "regressor_daily_spend.pkl")
        self.reg_features = joblib.load(MODELS_DIR / "regressor_features.pkl")
        self.classifier = joblib.load(MODELS_DIR / "classifier_category.pkl")
        self.clf_features = joblib.load(MODELS_DIR / "classifier_features.pkl")
        self.overspend_clf = joblib.load(MODELS_DIR / "classifier_overspending.pkl")
        self.over_features = joblib.load(MODELS_DIR / "overspending_features.pkl")

        with open(FEATURES_DIR / "category_map.json") as f:
            self.cat_map = json.load(f)
        self.cat_map_inv = {int(v): k for k, v in self.cat_map.items()}

        self.users = pd.read_csv(OUTPUT_DIR / "users.csv")
        self.users['join_date'] = pd.to_datetime(self.users['join_date'])

        print("Loading expense data (this may take a moment)...")
        self.expenses = pd.read_csv(OUTPUT_DIR / "expenses.csv", keep_default_na=False)
        self.expenses['date'] = pd.to_datetime(self.expenses['date'])
        self.expenses['amount'] = self.expenses['amount'].astype(float)

        self.groups = pd.read_csv(OUTPUT_DIR / "groups.csv", keep_default_na=False)
        self.memberships = pd.read_csv(OUTPUT_DIR / "group_memberships.csv", keep_default_na=False)
        self.splits = pd.read_csv(OUTPUT_DIR / "expense_splits.csv", keep_default_na=False)

        self._build_user_stats()

    def _build_user_stats(self):
        print("Computing user statistics...")
        self.user_monthly = self.expenses.groupby(['user_id', self.expenses['date'].dt.to_period('M')]).agg(
            monthly_total=('amount', 'sum'),
            monthly_count=('amount', 'count'),
            monthly_mean=('amount', 'mean'),
        ).reset_index()
        self.user_monthly.columns = ['user_id', 'month', 'monthly_total', 'monthly_count', 'monthly_mean']
        self.user_monthly['month'] = self.user_monthly['month'].astype(str)

        self.user_cat_monthly = self.expenses.groupby(['user_id', self.expenses['date'].dt.to_period('M'), 'category']).agg(
            category_total=('amount', 'sum'),
            category_count=('amount', 'count'),
        ).reset_index()
        self.user_cat_monthly.columns = ['user_id', 'month', 'category', 'category_total', 'category_count']
        self.user_cat_monthly['month'] = self.user_cat_monthly['month'].astype(str)

        self.user_overall = self.expenses.groupby('user_id').agg(
            total_spent=('amount', 'sum'),
            total_transactions=('amount', 'count'),
            avg_transaction=('amount', 'mean'),
            std_transaction=('amount', 'std'),
        ).reset_index()
        self.user_overall['std_transaction'] = self.user_overall['std_transaction'].fillna(0)

        self.user_cat_overall = self.expenses.groupby(['user_id', 'category']).agg(
            total_spent=('amount', 'sum'),
            avg_spent=('amount', 'mean'),
            count=('amount', 'count'),
        ).reset_index()

    def get_user_profile(self, user_id: str) -> Dict:
        user_row = self.users[self.users['user_id'] == user_id]
        if len(user_row) == 0:
            return {"error": f"User {user_id} not found"}
        user = user_row.iloc[0].to_dict()

        stats = self.user_overall[self.user_overall['user_id'] == user_id]
        cat_breakdown = self.user_cat_overall[self.user_cat_overall['user_id'] == user_id]

        top_categories = cat_breakdown.nlargest(3, 'total_spent')[['category', 'total_spent', 'count']].to_dict('records')

        user_groups = self.memberships[self.memberships['user_id'] == user_id]['group_id'].tolist()
        group_details = self.groups[self.groups['group_id'].isin(user_groups)].to_dict('records')

        return {
            'user_id': user_id,
            'name': user['name'],
            'persona': user['persona'],
            'age': int(user['age']),
            'income': user['income'],
            'location_tier': user['location_tier'],
            'total_spent': float(stats['total_spent'].values[0]) if len(stats) > 0 else 0,
            'total_transactions': int(stats['total_transactions'].values[0]) if len(stats) > 0 else 0,
            'avg_transaction': float(stats['avg_transaction'].values[0]) if len(stats) > 0 else 0,
            'top_categories': top_categories,
            'num_groups': len(user_groups),
            'group_types': [g['group_type'] for g in group_details],
        }

    def get_spending_breakdown(self, user_id: str, period: str = "last_30d") -> Dict:
        if period == "last_30d":
            cutoff = self.expenses['date'].max() - timedelta(days=30)
        elif period == "last_90d":
            cutoff = self.expenses['date'].max() - timedelta(days=90)
        elif period == "last_12m":
            cutoff = self.expenses['date'].max() - timedelta(days=365)
        else:
            cutoff = self.expenses['date'].min()

        user_exp = self.expenses[(self.expenses['user_id'] == user_id) & (self.expenses['date'] >= cutoff)]

        if len(user_exp) == 0:
            return {"user_id": user_id, "period": period, "total_spent": 0, "breakdown": {}}

        breakdown = user_exp.groupby('category').agg(
            total=('amount', 'sum'),
            count=('amount', 'count'),
            avg=('amount', 'mean'),
        ).to_dict('index')

        result = {
            'user_id': user_id,
            'period': period,
            'total_spent': float(user_exp['amount'].sum()),
            'total_transactions': int(len(user_exp)),
            'breakdown': {k: {kk: float(vv) for kk, vv in v.items()} for k, v in breakdown.items()},
        }
        return result

    def detect_overspending_patterns(self, user_id: str) -> Dict:
        user_exp = self.expenses[self.expenses['user_id'] == user_id].sort_values('date')
        if len(user_exp) == 0:
            return {"user_id": user_id, "alerts": [], "risk_level": "low"}

        daily = user_exp.groupby('date').agg(total=('amount', 'sum')).reset_index()
        daily = daily.sort_values('date')

        if len(daily) < 7:
            return {"user_id": user_id, "alerts": [], "risk_level": "low"}

        rolling_7d = daily['total'].rolling(7, min_periods=1).mean()
        rolling_30d = daily['total'].rolling(30, min_periods=1).mean()

        recent_7d = rolling_7d.iloc[-1]
        recent_30d = rolling_30d.iloc[-1]

        alerts = []
        if recent_7d > recent_30d * 1.5:
            alerts.append({
                'type': 'spending_spike',
                'message': f"Your recent 7-day average (${recent_7d:.2f}/day) is {recent_7d/recent_30d:.1f}x your 30-day average (${recent_30d:.2f}/day)",
                'severity': 'high' if recent_7d > recent_30d * 2 else 'medium',
            })

        recent_exp = user_exp[user_exp['date'] >= user_exp['date'].max() - timedelta(days=30)]
        cat_spending = recent_exp.groupby('category')['amount'].sum()
        overall_avg_cat = self.user_cat_overall[self.user_cat_overall['user_id'] == user_id].groupby('category')['total_spent'].mean()

        for cat in cat_spending.index:
            if cat in overall_avg_cat.index:
                ratio = cat_spending[cat] / (overall_avg_cat[cat] + 1)
                if ratio > 2:
                    alerts.append({
                        'type': 'category_spike',
                        'category': cat,
                        'message': f"Your {cat} spending this month (${cat_spending[cat]:.2f}) is {ratio:.1f}x your average",
                        'severity': 'high' if ratio > 3 else 'medium',
                    })

        negative_expenses = user_exp[user_exp['amount'] < 0]
        if len(negative_expenses) > 0:
            alerts.append({
                'type': 'negative_amounts',
                'message': f"You have {len(negative_expenses)} refund/credit entries totaling ${abs(negative_expenses['amount'].sum()):.2f}",
                'severity': 'info',
            })

        risk_level = 'low'
        if any(a['severity'] == 'high' for a in alerts):
            risk_level = 'high'
        elif any(a['severity'] == 'medium' for a in alerts):
            risk_level = 'medium'

        return {"user_id": user_id, "alerts": alerts, "risk_level": risk_level}

    def get_recommendations(self, user_id: str) -> Dict:
        profile = self.get_user_profile(user_id)
        if 'error' in profile:
            return profile

        breakdown = self.get_spending_breakdown(user_id, "last_30d")
        cat_totals = breakdown.get('breakdown', {})

        top_cats = sorted(cat_totals.items(), key=lambda x: x[1]['total'], reverse=True)[:3]

        recommendations = []
        for cat, data in top_cats:
            cat_name = cat
            if cat_name in CATEGORY_SUGGESTIONS:
                if data['total'] > profile.get('avg_transaction', 0) * 5:
                    tips = CATEGORY_SUGGESTIONS[cat_name]['reduce']
                else:
                    tips = CATEGORY_SUGGESTIONS[cat_name]['optimize']
                recommendations.append({
                    'category': cat_name,
                    'monthly_spend': round(data['total'], 2),
                    'transaction_count': data['count'],
                    'tips': tips[:2],
                })

        persona = profile['persona']
        persona_tips = {
            'frugal': "You're naturally careful with spending. Consider whether you're being too restrictive - some quality-of-life spending is healthy.",
            'conservative': "You maintain a good balance. Look for optimization opportunities rather than cutting back.",
            'moderate': "You spend within reasonable limits. Focus on redirecting spending toward value-aligned categories.",
            'lifestyle': "Your spending reflects an active lifestyle. Consider setting specific savings goals to balance enjoyment with future security.",
            'spender': "You enjoy spending freely. Setting category-specific budgets can help maintain your lifestyle while building savings.",
            'occasional_splurger': "Your occasional large purchases can derail budgets. Plan for splurges by setting aside a 'fun money' fund monthly.",
        }
        recommendations.append({
            'category': 'general',
            'persona_tip': persona_tips.get(persona, "Track your spending regularly to identify patterns."),
        })

        return {
            'user_id': user_id,
            'persona': persona,
            'recommendations': recommendations,
        }

    def get_group_insights(self, group_id: str) -> Dict:
        group_info = self.groups[self.groups['group_id'] == group_id]
        if len(group_info) == 0:
            return {"error": f"Group {group_id} not found"}
        group = group_info.iloc[0]

        group_exp = self.expenses[self.expenses['group_id'] == group_id]
        if len(group_exp) == 0:
            return {"group_id": group_id, "name": group['name'], "total_spent": 0}

        total_spent = float(group_exp['amount'].sum())
        cat_breakdown = group_exp.groupby('category')['amount'].sum().sort_values(ascending=False).to_dict()

        member_ids = self.memberships[self.memberships['group_id'] == group_id]['user_id'].tolist()
        member_spending = {}
        for mid in member_ids:
            member_exp = group_exp[group_exp['user_id'] == mid]
            member_spending[mid] = {
                'total_paid': float(member_exp['amount'].sum()),
                'transactions': int(len(member_exp)),
            }

        group_splits = self.splits[self.splits['expense_id'].isin(group_exp['expense_id'])]
        balance = defaultdict(float)
        for _, s in group_splits.iterrows():
            expense = group_exp[group_exp['expense_id'] == s['expense_id']]
            if len(expense) > 0 and s['user_id'] == expense.iloc[0]['user_id']:
                balance[s['user_id']] += float(expense.iloc[0]['amount']) - float(s['amount'])
            else:
                balance[s['user_id']] -= float(s['amount'])

        settlements_for_group = pd.read_csv(OUTPUT_DIR / "settlements.csv", keep_default_na=False)
        group_settled = settlements_for_group[settlements_for_group['group_id'] == group_id]
        settled_amount = float(group_settled[group_settled['status'] == 'completed']['amount'].sum())

        return {
            'group_id': group_id,
            'name': group['name'],
            'type': group['group_type'],
            'total_spent': total_spent,
            'category_breakdown': {k: round(v, 2) for k, v in cat_breakdown.items()},
            'members': member_spending,
            'unsettled_balance': {k: round(v, 2) for k, v in balance.items()},
            'settled_amount': round(settled_amount, 2),
            'settlement_efficiency': round(settled_amount / (total_spent + 1) * 100, 1),
        }

    def predict_daily_spend(self, user_id: str, target_date: str) -> Dict:
        user_row = self.users[self.users['user_id'] == user_id]
        if len(user_row) == 0:
            return {"error": f"User {user_id} not found"}
        user = user_row.iloc[0]

        target = pd.to_datetime(target_date)
        user_exp = self.expenses[self.expenses['user_id'] == user_id].sort_values('date')

        recent_7d = user_exp[user_exp['date'] >= target - timedelta(days=7)]
        recent_14d = user_exp[user_exp['date'] >= target - timedelta(days=14)]
        recent_30d = user_exp[user_exp['date'] >= target - timedelta(days=30)]

        feature_dict = {
            'weekday': target.dayofweek,
            'is_weekend': int(target.dayofweek >= 5),
            'day_of_month': target.day,
            'month': target.month,
            'year': target.year,
            'is_payday': int(target.day in [1, 2, 3, 15, 16]),
            'quarter': target.quarter,
            'week_of_year': target.isocalendar()[1],
            'rolling_7d_mean': recent_7d['amount'].sum() / 7 if len(recent_7d) > 0 else user.get('spending_multiplier', 1) * 50,
            'rolling_7d_std': recent_7d.groupby('date')['amount'].sum().std() if len(recent_7d) > 1 else 0,
            'rolling_7d_sum': recent_7d['amount'].sum() if len(recent_7d) > 0 else 0,
            'rolling_14d_mean': recent_14d['amount'].sum() / 14 if len(recent_14d) > 0 else user.get('spending_multiplier', 1) * 50,
            'rolling_14d_std': recent_14d.groupby('date')['amount'].sum().std() if len(recent_14d) > 1 else 0,
            'rolling_30d_mean': recent_30d['amount'].sum() / 30 if len(recent_30d) > 0 else user.get('spending_multiplier', 1) * 50,
            'rolling_30d_std': recent_30d.groupby('date')['amount'].sum().std() if len(recent_30d) > 1 else 0,
            'rolling_30d_sum': recent_30d['amount'].sum() if len(recent_30d) > 0 else 0,
            'prev_day_spend': recent_7d[recent_7d['date'] == target - timedelta(days=1)]['amount'].sum() if len(recent_7d) > 0 else 0,
            'spend_vs_7d_avg': 1.0,
            'age': user['age'],
            'income': user['income'],
            'spending_multiplier': user['spending_multiplier'],
            'activity_rate': user['activity_rate'],
            'social_tendency': user['social_tendency'],
            'consistency': user['consistency'],
            'splurge_probability': user['splurge_probability'],
            'daily_lambda': user['daily_lambda'],
            'persona_conservative': int(user['persona'] == 'conservative'),
            'persona_frugal': int(user['persona'] == 'frugal'),
            'persona_lifestyle': int(user['persona'] == 'lifestyle'),
            'persona_moderate': int(user['persona'] == 'moderate'),
            'persona_occasional_splurger': int(user['persona'] == 'occasional_splurger'),
            'persona_spender': int(user['persona'] == 'spender'),
            'loc_metro': int(user['location_tier'] == 'metro'),
            'loc_tier2': int(user['location_tier'] == 'tier2'),
            'loc_tier3': int(user['location_tier'] == 'tier3'),
            'daily_count': len(recent_7d) / 7 if len(recent_7d) > 0 else 1.5,
            'daily_neg_count': len(recent_7d[recent_7d['amount'] < 0]) / 7 if len(recent_7d) > 0 else 0,
            'daily_recurring_count': len(recent_7d[recent_7d['is_recurring'] == True]) / 7 if len(recent_7d) > 0 else 0,
            'daily_group_count': len(recent_7d[recent_7d['is_group_expense'] == True]) / 7 if len(recent_7d) > 0 else 0,
        }

        missing_cols = [c for c in self.reg_features if c not in feature_dict]
        for c in missing_cols:
            feature_dict[c] = 0

        X = pd.DataFrame([{c: feature_dict.get(c, 0) for c in self.reg_features}])
        pred_log = self.regressor.predict(X)[0]
        pred_amount = np.expm1(pred_log)

        overspend_prob = self.overspend_clf.predict_proba(X[self.over_features])[0][1]

        return {
            'user_id': user_id,
            'target_date': target_date,
            'predicted_spend': round(float(pred_amount), 2),
            'overspending_probability': round(float(overspend_prob), 4),
            'overspending_risk': 'high' if overspend_prob > 0.7 else ('medium' if overspend_prob > 0.3 else 'low'),
            'recent_7d_avg': round(float(feature_dict['rolling_7d_mean']), 2),
            'recent_30d_avg': round(float(feature_dict['rolling_30d_mean']), 2),
        }

    def generate_full_report(self, user_id: str) -> Dict:
        profile = self.get_user_profile(user_id)
        breakdown = self.get_spending_breakdown(user_id, "last_30d")
        alerts = self.detect_overspending_patterns(user_id)
        recommendations = self.get_recommendations(user_id)

        latest_date = self.expenses['date'].max()
        today_str = latest_date.strftime('%Y-%m-%d')
        prediction = self.predict_daily_spend(user_id, (latest_date + timedelta(days=1)).strftime('%Y-%m-%d'))

        user_groups = self.memberships[self.memberships['user_id'] == user_id]['group_id'].tolist()
        group_insights = []
        for gid in user_groups[:5]:
            group_insights.append(self.get_group_insights(gid))

        return {
            'user_profile': profile,
            'spending_breakdown': breakdown,
            'overspending_alerts': alerts,
            'recommendations': recommendations,
            'spend_prediction': prediction,
            'group_insights': group_insights[:3],
        }


def main():
    engine = ExpenseInsightEngine()

    sample_users = engine.users['user_id'].sample(5, random_state=42).tolist()
    for uid in sample_users:
        print(f"\n{'='*60}")
        print(f"INSIGHT REPORT: {uid}")
        print(f"{'='*60}")

        profile = engine.get_user_profile(uid)
        print(f"\n--- Profile ---")
        print(f"  Name: {profile['name']}, Persona: {profile['persona']}, Age: {profile['age']}, Income: ${profile['income']:,.0f}")
        print(f"  Total Spent: ${profile['total_spent']:,.0f}, Transactions: {profile['total_transactions']}")
        print(f"  Top Categories: {profile['top_categories']}")

        breakdown = engine.get_spending_breakdown(uid, "last_30d")
        print(f"\n--- 30-Day Breakdown ---")
        print(f"  Total: ${breakdown['total_spent']:,.2f}")
        for cat, data in sorted(breakdown['breakdown'].items(), key=lambda x: x[1]['total'], reverse=True)[:5]:
            print(f"    {cat:20s}: ${data['total']:,.2f} ({data['count']} txns)")

        alerts = engine.detect_overspending_patterns(uid)
        print(f"\n--- Overspending Alerts (Risk: {alerts['risk_level']}) ---")
        for a in alerts['alerts'][:3]:
            print(f"  [{a['severity']}] {a['message']}")

        recs = engine.get_recommendations(uid)
        print(f"\n--- Recommendations ---")
        for rec in recs['recommendations']:
            if 'category' in rec and rec['category'] != 'general':
                print(f"  {rec['category']}: ${rec.get('monthly_spend', 0):.2f}")
                for tip in rec.get('tips', []):
                    print(f"    - {tip}")
            else:
                print(f"  General: {rec.get('persona_tip', '')}")

        prediction = engine.predict_daily_spend(uid, (engine.expenses['date'].max() + timedelta(days=1)).strftime('%Y-%m-%d'))
        print(f"\n--- Tomorrow's Prediction ---")
        print(f"  Predicted spend: ${prediction['predicted_spend']:.2f}")
        print(f"  Overspending prob: {prediction['overspending_probability']:.1%} ({prediction['overspending_risk']})")

    print("\n\nGenerating full report for first sample user...")
    full_report = engine.generate_full_report(sample_users[0])

    report_path = Path("../output/sample_report.json")
    with open(report_path, 'w') as f:
        json.dump(full_report, f, indent=2, default=str)
    print(f"Full report saved to {report_path}")

    print("\n" + "=" * 60)
    print("INSIGHT ENGINE DEMO COMPLETE")
    print("=" * 60)


if __name__ == "__main__":
    from collections import defaultdict
    main()