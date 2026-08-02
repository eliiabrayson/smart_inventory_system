"""Generate model_simple.pkl matching the 11-feature layout (5 base + 6 contextual).
Uses only stdlib — no numpy/sklearn required.
"""
import pickle
from pathlib import Path

# Coefficients: intercept + 5 base + 6 contextual
# contextual order: temperature, precipitation, humidity, calendar_event, lead_time, market_trend
WEIGHTS = [
    0.0,    # intercept
    1.8,    # base[0]
    -0.8,   # base[1]
    0.0,    # base[2]
    0.0,    # base[3]
    0.0,    # base[4]
    0.05,   # temperature
    -0.3,   # precipitation
    0.01,   # humidity
    0.4,    # calendar_event
    -0.15,  # lead_time
    0.7,    # market_trend
]

OUT = Path(__file__).parent / "model_simple.pkl"
BACKUP = Path(__file__).parent / "model.joblib.bak"
OLD = Path(__file__).parent / "model.joblib"

if __name__ == "__main__":
    with open(OUT, "wb") as f:
        pickle.dump(WEIGHTS, f)
    print(f"Saved simple model ({len(WEIGHTS)} coeffs) to {OUT}")
    if OLD.exists() and not BACKUP.exists():
        OLD.rename(BACKUP)
        print(f"Renamed outdated {OLD.name} -> {BACKUP.name}")
