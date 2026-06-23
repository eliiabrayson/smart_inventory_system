from fastapi import FastAPI
from pydantic import BaseModel
import joblib
import pickle
from pathlib import Path
import numpy as np


MODEL_PATH = Path(__file__).parent / "model.joblib"
MODEL_SIMPLE = Path(__file__).parent / "model_simple.pkl"
app = FastAPI(title="Smart Inventory Predictive API")


class PredictRequest(BaseModel):
    features: list[float]


class PredictResponse(BaseModel):
    prediction: float


def load_model():
    if MODEL_PATH.exists():
        return ("joblib", joblib.load(MODEL_PATH))
    if MODEL_SIMPLE.exists():
        with open(MODEL_SIMPLE, "rb") as f:
            w = pickle.load(f)
        return ("simple", w)
    return None


model = load_model()


@app.on_event("startup")
def startup_event():
    global model
    if model is None:
        # attempt to load; if not present instruct to run training
        print("Model not found at", MODEL_PATH)


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    global model
    if model is None:
        return {"prediction": 0.0}
    mtype, mobj = model
    arr = np.array(req.features, dtype=float).reshape(1, -1)
    if mtype == "joblib":
        pred = mobj.predict(arr)
        return {"prediction": float(pred[0])}
    # simple linear model: mobj is weight vector [b0, b1, ...]
    if mtype == "simple":
        xb = np.hstack([np.ones((arr.shape[0], 1)), arr])
        pred = xb @ mobj
        return {"prediction": float(pred[0])}
    return {"prediction": 0.0}


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": model is not None}
