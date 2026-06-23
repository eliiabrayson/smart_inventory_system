# Predictive API (Python)

This folder contains a small FastAPI service and a training script for a predictive model used by the Smart Modules.

Quick start

1. Create a virtual environment and install dependencies:

```bash
python -m venv .venv
source .venv/Scripts/activate   # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

2. Train model (creates `model.joblib`):

```bash
python train_model.py
```

3. Run the API locally:

```bash
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

4. Test prediction:

```bash
curl -X POST http://localhost:8000/predict -H "Content-Type: application/json" -d '{"features": [0.1, 0.2, 0.3, 0.4, 0.5]}'
```

Notes
- Uses `RandomForestRegressor` as a strong baseline. For production-grade performance consider LightGBM/XGBoost and hyperparameter tuning.
- If you have historical inventory or sales data, update `train_model.py` to load relevant features and target.
