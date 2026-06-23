from fastapi import FastAPI
from pydantic import BaseModel
import joblib
import pickle
from pathlib import Path
import numpy as np
from typing import Optional
import requests
from datetime import date


MODEL_PATH = Path(__file__).parent / "model.joblib"
MODEL_SIMPLE = Path(__file__).parent / "model_simple.pkl"
app = FastAPI(title="Smart Inventory Predictive API")


class Weather(BaseModel):
    temperature: Optional[float] = None
    precipitation: Optional[float] = None
    humidity: Optional[float] = None


class PredictRequest(BaseModel):
    features: list[float]
    weather: Optional[Weather] = None
    season: Optional[str] = None  # spring, summer, autumn, winter
    is_holiday: Optional[bool] = None
    trend_score: Optional[float] = None
    event_count: Optional[int] = None
    # If provided, server can fetch weather automatically for this lat/lon
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    fetch_weather: Optional[bool] = False
    # Optional ISO country code for holiday lookup (e.g. 'US', 'KE')
    country_code: Optional[str] = None


class PredictResponse(BaseModel):
    prediction: float


def load_model():
    if MODEL_PATH.exists():
        try:
            return ("joblib", joblib.load(MODEL_PATH))
        except Exception as ex:
            print('Failed to load joblib model:', ex)
            # fall through to try simple model
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
        # attempt to load; if not present instruct to run training
        print("Model not found at", MODEL_PATH)


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    return {"prediction": float(predict_from_request(req))}


def predict_from_request(req: PredictRequest) -> float:
    global model
    if model is None:
        return 0.0
    mtype, mobj = model
    base = np.array(req.features, dtype=float).reshape(1, -1)

    # Optionally fetch weather if requested and lat/lon provided
    weather_vals = [0.0, 0.0, 0.0]
    if req.fetch_weather and req.latitude is not None and req.longitude is not None:
        try:
            wurl = f"https://api.open-meteo.com/v1/forecast?latitude={req.latitude}&longitude={req.longitude}&current_weather=true"
            r = requests.get(wurl, timeout=5)
            if r.status_code == 200:
                j = r.json()
                cw = j.get('current_weather', {})
                # open-meteo provides temperature and windspeed; use temperature, and set others to 0
                weather_vals[0] = float(cw.get('temperature', 0.0))
        except Exception as ex:
            print('Weather fetch failed:', ex)
    # If client provided weather, prefer those values
    if req.weather is not None:
        weather_vals[0] = float(req.weather.temperature or weather_vals[0])
        weather_vals[1] = float(req.weather.precipitation or weather_vals[1])
        weather_vals[2] = float(req.weather.humidity or weather_vals[2])

    # Season encoding (simple ordinal)
    season_map = {'spring': 0.0, 'summer': 1.0, 'autumn': 2.0, 'fall': 2.0, 'winter': 3.0}
    season_val = float(season_map.get((req.season or '').lower(), -1.0))

    # Determine holiday: prefer provided flag, otherwise try lookup by country_code
    is_holiday_val = 1.0 if req.is_holiday else 0.0
    if req.is_holiday is None and req.country_code:
        try:
            year = date.today().year
            holiday_url = f"https://date.nager.at/api/v3/PublicHolidays/{year}/{req.country_code}"
            r = requests.get(holiday_url, timeout=5)
            if r.status_code == 200:
                holidays = r.json()
                today_iso = date.today().isoformat()
                for h in holidays:
                    if h.get('date') == today_iso:
                        is_holiday_val = 1.0
                        break
        except Exception as ex:
            print('Holiday lookup failed:', ex)
    trend_val = float(req.trend_score or 0.0)
    events_val = float(req.event_count or 0.0)

    extras = np.array([[weather_vals[0], weather_vals[1], weather_vals[2], season_val, is_holiday_val, trend_val, events_val]])

    arr = np.hstack([base, extras])

    # Ensure shape matches model expectation if possible
    expected = None
    try:
        expected = int(getattr(mobj, 'n_features_in_', -1))
    except Exception:
        expected = -1
    if expected > 0 and arr.shape[1] != expected:
        # Pad with zeros or truncate to match expected feature length
        if arr.shape[1] < expected:
            pad = np.zeros((arr.shape[0], expected - arr.shape[1]))
            arr = np.hstack([arr, pad])
        else:
            arr = arr[:, :expected]
    if mtype == "joblib":
        pred = mobj.predict(arr)
        return float(pred[0])
    # simple linear model: mobj is weight vector [b0, b1, ...]
    if mtype == "simple":
        try:
            expected_coeffs = getattr(mobj, 'shape', None)
            if expected_coeffs is not None and len(mobj) >= 1:
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


class BatchItem(BaseModel):
    features: list[float]
    weather: Optional[Weather] = None
    season: Optional[str] = None
    is_holiday: Optional[bool] = None
    trend_score: Optional[float] = None
    event_count: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    fetch_weather: Optional[bool] = False
    country_code: Optional[str] = None


class BatchPredictRequest(BaseModel):
    items: list[BatchItem]


@app.post('/forecast_batch')
def forecast_batch(req: BatchPredictRequest):
    results = []
    for it in req.items:
        preq = PredictRequest(
            features=it.features,
            weather=it.weather,
            season=it.season,
            is_holiday=it.is_holiday,
            trend_score=it.trend_score,
            event_count=it.event_count,
            latitude=it.latitude,
            longitude=it.longitude,
            fetch_weather=it.fetch_weather,
            country_code=it.country_code,
        )
        pred = predict_from_request(preq)
        results.append({'prediction': float(pred)})
    return {'results': results}


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": model is not None}
