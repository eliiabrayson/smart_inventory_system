"""Train an extended predictive model with contextual features:
weather (temperature, precipitation, humidity), calendar events, lead time, market trend.
Saves model.joblib into the python_api directory.

Run:
    python python_api/train_model_extended.py
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
    # contextual: temperature, precipitation, humidity, calendar_events, lead_time, market_trend
    temp = rng.normal(loc=25, scale=7, size=(n, 1))
    precip = rng.exponential(scale=1.0, size=(n, 1))
    humidity = rng.uniform(30, 90, size=(n, 1))
    calendar_events = rng.poisson(lam=0.5, size=(n, 1))
    lead_time = rng.uniform(1, 14, size=(n, 1))
    market_trend = rng.normal(scale=0.5, size=(n, 1))

    X_ctx = np.hstack([temp, precip, humidity, calendar_events, lead_time, market_trend])
    X = np.hstack([X_base, X_ctx])

    y = (
        X_base[:, 0] * 1.8
        - X_base[:, 1] * 0.8
        + 0.05 * X_ctx[:, 0]   # temperature
        - 0.3 * X_ctx[:, 1]    # precipitation
        + 0.01 * X_ctx[:, 2]   # humidity
        + 0.4 * X_ctx[:, 3]    # calendar events
        - 0.15 * X_ctx[:, 4]   # lead time (longer lead = less urgent demand)
        + 0.7 * X_ctx[:, 5]    # market trend
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
