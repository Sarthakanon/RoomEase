# ML Pipeline Scripts

This directory contains scripts for generating and processing training data for the AI Spending Analytics feature.

## Scripts

### 1. generate_synthetic_data.py

Generates realistic synthetic expense data with patterns and seasonality.

**Usage:**
```bash
python3 generate_synthetic_data.py \
  --output data/synthetic/synthetic_expenses.csv \
  --count 100000 \
  --users 1000 \
  --start-date 2022-01-01 \
  --end-date 2024-12-31 \
  --seed 42
```

**Features:**
- Generates 100,000+ expense records
- Realistic spending patterns (daily, weekly, monthly, irregular)
- Seasonal adjustments (holidays, summer, back-to-school)
- Multiple expense categories (Food, Transport, Utilities, etc.)
- User profiles with different income levels and spending habits

**Output:**
CSV file with columns: `user_id`, `date_time`, `category`, `amount`, `currency`, `pattern_type`

### 2. split_data.py

Splits expense data into train/validation/test sets with temporal ordering preservation.

**Usage:**
```bash
python3 split_data.py \
  --input data/synthetic/synthetic_expenses.csv \
  --output-dir data/splits \
  --train-ratio 0.8 \
  --val-ratio 0.1 \
  --test-ratio 0.1 \
  --prefix synthetic_expenses
```

**Features:**
- Temporal split (80/10/10 by default)
- Preserves chronological ordering
- Prevents data leakage
- Outputs separate CSV files for train/val/test

**Output:**
- `{prefix}_train.csv` - Training set (80%)
- `{prefix}_val.csv` - Validation set (10%)
- `{prefix}_test.csv` - Test set (10%)

### 3. verify_splits.py

Verifies that data splits maintain temporal ordering and have no data leakage.

**Usage:**
```bash
python3 verify_splits.py
```

**Checks:**
- ✓ Temporal ordering (train < val < test)
- ✓ No data leakage between sets
- ✓ Split ratios match expected values
- ✓ Each set is properly sorted by date

## Example Workflow

```bash
# 1. Generate synthetic data
python3 generate_synthetic_data.py \
  --output data/synthetic/synthetic_expenses.csv \
  --count 100000 \
  --users 1000

# 2. Split into train/val/test
python3 split_data.py \
  --input data/synthetic/synthetic_expenses.csv \
  --output-dir data/splits \
  --prefix synthetic_expenses

# 3. Verify splits
python3 verify_splits.py
```

## Data Statistics

After running the example workflow, you should see:
- **Total records:** ~100,000 expense records
- **Date range:** 2022-01-01 to 2024-12-31
- **Categories:** 10 expense categories
- **Patterns:** Daily, weekly, monthly, and irregular spending patterns
- **Train/Val/Test:** 80%/10%/10% split with no temporal overlap

## Requirements

See `../requirements.txt` for dependencies:
- pandas
- numpy
- python 3.10+
