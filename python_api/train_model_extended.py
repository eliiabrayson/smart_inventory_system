"""Train an extended predictive model that includes contextual features.
This script creates synthetic data for base features and contextual features
(weather, season, holiday, trend, events) and trains a RandomForestRegressor.
Saves model.joblib into the python_api directory.

Run in a conda env with scikit-learn available for best results:
    conda run -n smartapi python python_api/train_model_extended.py
"""
from pathlib import Path
import numpy as np
import joblib

from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error

OUT = Path(__file__).parent / "model.joblib"


def make_synthetic(n=2000, base_dim=5, random_state=42):
    rng = np.random.default_rng(random_state)
    X_base = rng.normal(size=(n, base_dim))
    # contextual features
    # temperature (C), precipitation (mm), humidity (%), season(0-3), is_holiday(0/1), trend_score, event_count
    temp = rng.normal(loc=25, scale=7, size=(n, 1))
    precip = rng.exponential(scale=1.0, size=(n, 1))
    humidity = rng.uniform(30, 90, size=(n, 1))
    season = rng.integers(0, 4, size=(n, 1))
    is_holiday = rng.choice([0, 1], size=(n, 1), p=[0.95, 0.05])
    trend = rng.normal(scale=0.5, size=(n, 1))
    events = rng.poisson(lam=0.5, size=(n, 1))

    X_ctx = np.hstack([temp, precip, humidity, season.astype(float), is_holiday.astype(float), trend, events])
    X = np.hstack([X_base, X_ctx])

    # Create target as combination of base and contextual signals (simulate demand)
    y = (
        X_base[:, 0] * 1.8
        - X_base[:, 1] * 0.8
        + 0.05 * X_ctx[:, 0]  # temp
        - 0.3 * X_ctx[:, 1]  # precip
        + 0.01 * X_ctx[:, 2]  # humidity
        + 0.5 * X_ctx[:, 4]  # holiday bump
        + 0.7 * X_ctx[:, 5]  # trend
        + rng.normal(scale=0.6, size=n)
    )
    return X, y


def train_and_save(path=OUT):
    X, y = make_synthetic()
    X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, random_state=42)
    model = RandomForestRegressor(n_estimators=300, max_depth=16, random_state=42, n_jobs=-1)
    print("Training model...")
    model.fit(X_train, y_train)
    preds = model.predict(X_val)
    mse = mean_squared_error(y_val, preds)
    print(f"Validation MSE: {mse:.4f}")
    joblib.dump(model, path)
    print(f"Saved model to {path}")


if __name__ == "__main__":
    train_and_save()
