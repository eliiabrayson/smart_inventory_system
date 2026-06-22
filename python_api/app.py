from fastapi import FastAPI
from pydantic import BaseModel
import joblib
from pathlib import Path
import numpy as np


MODEL_PATH = Path(__file__).parent / "model.joblib"
app = FastAPI(title="Smart Inventory Predictive API")


class PredictRequest(BaseModel):
    features: list[float]


class PredictResponse(BaseModel):
    prediction: float


def load_model():
    if MODEL_PATH.exists():
        return joblib.load(MODEL_PATH)
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
    arr = np.array(req.features, dtype=float).reshape(1, -1)
    pred = model.predict(arr)
    return {"prediction": float(pred[0])}


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": model is not None}
