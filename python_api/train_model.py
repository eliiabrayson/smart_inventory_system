"""Train a simple predictive model and save it to disk.
This script creates a small RandomForest regressor trained on synthetic data
if no suitable CSV is found. The saved model is `model.joblib`.
"""
from pathlib import Path
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error
import joblib


def load_data():
    sample_csv = Path("../sample_inventory.csv")
    if sample_csv.exists():
        df = pd.read_csv(sample_csv)
        # Attempt to pull numeric columns; fallback to synthetic
        nums = df.select_dtypes(include=["number"]).copy()
        if nums.shape[1] >= 2:
            X = nums.iloc[:, :-1].values
            y = nums.iloc[:, -1].values
            return X, y
    # Synthetic fallback
    rng = np.random.default_rng(123)
    X = rng.normal(size=(1000, 5))
    # create a target with some signal
    y = X[:, 0] * 2.0 + X[:, 1] * -1.5 + rng.normal(scale=0.5, size=1000)
    return X, y


def train_and_save(path: Path = Path("model.joblib")):
    X, y = load_data()
    X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, random_state=42)
    model = RandomForestRegressor(n_estimators=200, max_depth=12, random_state=42, n_jobs=-1)
    model.fit(X_train, y_train)
    preds = model.predict(X_val)
    mse = mean_squared_error(y_val, preds)
    print(f"Validation MSE: {mse:.4f}")
    joblib.dump(model, path)
    print(f"Saved model to {path}")


if __name__ == "__main__":
    train_and_save()
