<!--
File: README.md
What does this file do?
    Documents the complete Nepal-first expense insight project, dataset workflow,
    model results, notebooks, and web application integration.
Methods/functions this file contains:
    None. This is project documentation.
Date and Day of last modification:
    2026-05-21, Thursday.
-->

# Nepal Expense Insight Model

This project creates a Nepal-first expense dataset, trains financial insight
models, and integrates the final model into a Go + React expense tracking web
application.

The main objective is to help users understand spending behavior, predict
future expenses, detect unusual spending, manage budgets, and collaborate on
shared project expenses such as roommate or trip expenses.

## Final Answer: Best Performing Model

The **budget risk classifier** performed the best.

Final metrics:

| Model | Main Metric | Result | Status |
|---|---:|---:|---|
| Budget risk | AUC / F1 | 0.922 / 0.896 | Best model |
| Monthly forecast | R2 / MAE | 0.416 / NPR 32,291 | Good for planning |
| Anomaly detection | AUC / F1 | 0.779 / 0.432 | Usable, moderate |
| Shared settlement risk | AUC / F1 | 0.701 / 0.341 | Usable, weakest |

The budget model is strongest because it has the best combination of AUC, F1,
precision, and recall.

## Project Structure

```text
output_v2/                 Final generated Nepal finance dataset
features_v2_nepal/         Final model-ready feature tables
models_v2_nepal/           Final saved model bundle
assistant_v2/              App-facing model wrapper and insight engine
generators_v2/             Nepal-first dataset generator
notebooks_v2/              Teacher-friendly Jupyter notebooks
web/                       Go + React expense tracking web app
```

## Teacher-Friendly Notebooks

Open these notebooks in order:

```text
notebooks_v2/01_dataset_creation_v2.ipynb
notebooks_v2/02_feature_engineering_v2.ipynb
notebooks_v2/03_model_training_evaluation_v2.ipynb
notebooks_v2/04_application_integration_v2.ipynb
```

They explain:

- dataset design
- feature engineering
- model training and evaluation
- model integration into an application

## Dataset

The final V2 dataset is Nepal-focused and uses NPR as the normalized modeling
currency.

It includes:

- users
- income events
- budgets
- goals
- personal expenses
- shared project expenses
- split records
- recurring payments
- currency rates
- festival calendar

Final generated dataset size:

```text
Users: 300
Expenses: 385,340
Shared expenses: 25,237
Expense splits: 121,468
Recurring payments: 39,755
```

## Models

The final saved models are in:

```text
models_v2_nepal/
```

Models trained:

- monthly spend forecast
- budget risk classifier
- daily anomaly detector
- spending profile clustering
- shared settlement risk classifier

The app-facing model wrapper is:

```python
from assistant_v2.finance_assistant import FinanceAssistantV2

assistant = FinanceAssistantV2("models_v2_nepal")
response = assistant.generate_insights(payload)
```

## Validation

Run:

```bash
python validate_model_bundle_v2.py --models-dir models_v2_nepal --data-dir output_v2
```

Expected result:

```text
Finance Assistant V2 bundle validation passed
```

## Regenerate Dataset

```bash
python main_v2.py --users 300 --groups 120 --output-dir output_v2
```

## Rebuild Features

```bash
python feature_engineering_v2.py --input-dir output_v2 --output-dir features_v2_nepal
```

## Retrain Models

```bash
python train_models_v2.py --input-dir output_v2 --features-dir features_v2_nepal --models-dir models_v2_nepal
```

## Web Application

The web app is inside:

```text
web/
```

It includes:

- Go backend
- React frontend
- project-based shared expenses
- expense creation
- model-backed insights
- Python model bridge

Run from the `web` directory:

```powershell
$env:GOTELEMETRY='off'
go run ./server
```

Then open:

```text
http://localhost:8080
```

## Important Note

The model is trained on synthetic but Nepal-focused data. It is suitable for a
prototype, demo, and first integration. For production, it should be calibrated
or retrained with real user data once available.
