"""Lightweight training script that does not require scikit-learn.
Uses a linear regression closed-form solution (normal equation) on synthetic or CSV numeric data.
Saves model coefficients to `model_simple.pkl`.
"""
from pathlib import Path
import numpy as np
import pandas as pd
import pickle


def load_data():
    sample_csv = Path("../sample_inventory.csv")
    if sample_csv.exists():
        df = pd.read_csv(sample_csv)
        nums = df.select_dtypes(include=["number"]).copy()
        if nums.shape[1] >= 2:
            X = nums.iloc[:, :-1].values
            y = nums.iloc[:, -1].values
            return X, y
    rng = np.random.default_rng(42)
    X = rng.normal(size=(500, 5))
    y = X[:, 0] * 1.8 + X[:, 1] * -1.2 + rng.normal(scale=0.5, size=500)
    return X, y


def train_and_save(path: Path = Path("model_simple.pkl")):
    X, y = load_data()
    # add intercept
    Xb = np.hstack([np.ones((X.shape[0], 1)), X])
    # normal equation with ridge for stability
    lam = 1e-3
    I = np.eye(Xb.shape[1])
    I[0, 0] = 0.0
    w = np.linalg.inv(Xb.T @ Xb + lam * I) @ (Xb.T @ y)
    with open(path, "wb") as f:
        pickle.dump(w, f)
    print(f"Saved simple linear model to {path}")


if __name__ == "__main__":
    train_and_save()
