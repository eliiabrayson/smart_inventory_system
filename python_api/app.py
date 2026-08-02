from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import pickle
from pathlib import Path
import numpy as np
from typing import Optional
import requests


MODEL_PATH = Path(__file__).parent / "model.joblib"
MODEL_SIMPLE = Path(__file__).parent / "model_simple.pkl"
app = FastAPI(title="Smart Inventory Predictive API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Contextual feature count: weather(3) + calendar_event(1) + lead_time(1) + market_trend(1)
CONTEXTUAL_DIM = 6


class Weather(BaseModel):
    temperature: Optional[float] = None
    precipitation: Optional[float] = None
    humidity: Optional[float] = None


class PredictRequest(BaseModel):
    features: list[float]
    weather: Optional[Weather] = None
    calendar_event: Optional[int] = None
    lead_time: Optional[float] = None
    market_trend: Optional[float] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    fetch_weather: Optional[bool] = False


class PredictResponse(BaseModel):
    prediction: float


def load_model():
    if MODEL_PATH.exists():
        try:
            return ("joblib", joblib.load(MODEL_PATH))
        except Exception as ex:
            print('Failed to load joblib model:', ex)
    if MODEL_SIMPLE.exists():
        try:
            with open(MODEL_SIMPLE, "rb") as f:
                w = pickle.load(f)
            return ("simple", w)
        except Exception as ex:
            print('Failed to load simple model:', ex)
    return None


model = load_model()


@app.on_event("startup")
def startup_event():
    global model
    if model is None:
        print("Model not found at", MODEL_PATH)


def _fetch_weather(latitude: float, longitude: float) -> list[float]:
    weather_vals = [0.0, 0.0, 0.0]
    try:
        wurl = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={latitude}&longitude={longitude}"
            f"&current=temperature_2m,relative_humidity_2m,precipitation"
        )
        r = requests.get(wurl, timeout=5)
        if r.status_code == 200:
            j = r.json()
            current = j.get('current', {})
            weather_vals[0] = float(current.get('temperature_2m', 0.0))
            weather_vals[1] = float(current.get('precipitation', 0.0))
            weather_vals[2] = float(current.get('relative_humidity_2m', 0.0))
    except Exception as ex:
        print('Weather fetch failed:', ex)
    return weather_vals


def predict_from_request(req: PredictRequest) -> float:
    global model
    if model is None:
        return 0.0
    mtype, mobj = model
    base = np.array(req.features, dtype=float).reshape(1, -1)

    weather_vals = [0.0, 0.0, 0.0]
    if req.fetch_weather and req.latitude is not None and req.longitude is not None:
        weather_vals = _fetch_weather(req.latitude, req.longitude)
    if req.weather is not None:
        weather_vals[0] = float(req.weather.temperature if req.weather.temperature is not None else weather_vals[0])
        weather_vals[1] = float(req.weather.precipitation if req.weather.precipitation is not None else weather_vals[1])
        weather_vals[2] = float(req.weather.humidity if req.weather.humidity is not None else weather_vals[2])

    calendar_event_val = float(req.calendar_event or 0.0)
    lead_time_val = float(req.lead_time or 0.0)
    market_trend_val = float(req.market_trend or 0.0)

    extras = np.array([[
        weather_vals[0], weather_vals[1], weather_vals[2],
        calendar_event_val, lead_time_val, market_trend_val,
    ]])

    arr = np.hstack([base, extras])

    expected = None
    try:
        expected = int(getattr(mobj, 'n_features_in_', -1))
    except Exception:
        expected = -1
    if expected > 0 and arr.shape[1] != expected:
        if arr.shape[1] < expected:
            pad = np.zeros((arr.shape[0], expected - arr.shape[1]))
            arr = np.hstack([arr, pad])
        else:
            arr = arr[:, :expected]

    if mtype == "joblib":
        pred = mobj.predict(arr)
        return float(pred[0])
    if mtype == "simple":
        try:
            if len(mobj) >= 1:
                expected_arr_len = len(mobj) - 1
                if arr.shape[1] < expected_arr_len:
                    pad = np.zeros((arr.shape[0], expected_arr_len - arr.shape[1]))
                    arr = np.hstack([arr, pad])
                elif arr.shape[1] > expected_arr_len:
                    arr = arr[:, :expected_arr_len]
        except Exception:
            pass
        xb = np.hstack([np.ones((arr.shape[0], 1)), arr])
        pred = xb @ mobj
        return float(pred[0])
    return 0.0


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    return {"prediction": float(predict_from_request(req))}


class BatchItem(BaseModel):
    features: list[float]
    weather: Optional[Weather] = None
    calendar_event: Optional[int] = None
    lead_time: Optional[float] = None
    market_trend: Optional[float] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    fetch_weather: Optional[bool] = False


class BatchPredictRequest(BaseModel):
    items: list[BatchItem]


@app.post('/forecast_batch')
def forecast_batch(req: BatchPredictRequest):
    results = []
    for it in req.items:
        preq = PredictRequest(
            features=it.features,
            weather=it.weather,
            calendar_event=it.calendar_event,
            lead_time=it.lead_time,
            market_trend=it.market_trend,
            latitude=it.latitude,
            longitude=it.longitude,
            fetch_weather=it.fetch_weather,
        )
        pred = predict_from_request(preq)
        results.append({'prediction': float(pred)})
    return {'results': results}


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": model is not None}
