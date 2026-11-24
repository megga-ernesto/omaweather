"""Fetch and normalize data from the public Open-Meteo endpoints."""

import json
import math
import re
import subprocess
import sys
from urllib.parse import urlencode

CONDITIONS = (
    "temperature_2m,apparent_temperature,relative_humidity_2m,"
    "wind_speed_10m,weather_code,is_day,wind_gusts_10m,pressure_msl,cloud_cover,visibility"
)
HOURLY = "temperature_2m,weather_code,is_day,precipitation_probability"
DAILY = (
    "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,"
    "sunrise,sunset,uv_index_max,precipitation_sum"
)
DAY_PATTERN = r"\d{4}-\d{2}-\d{2}"
TIME_PATTERN = DAY_PATTERN + r"T\d{2}:\d{2}"


def request(host, route, parameters):
    url = f"https://{host}/v1/{route}?{urlencode(parameters)}"
    result = subprocess.run(
        ["curl", "-q", "--fail", "--silent", "--show-error", "--proto", "=https",
         "--max-time", "10", "--max-filesize", "65536", url],
        check=True, capture_output=True, timeout=12,
    )
    data = json.loads(result.stdout)
    if not isinstance(data, dict) or data.get("error"):
        raise ValueError("Unexpected Open-Meteo response")
    return data


def number(value, lower, upper):
    if type(value) in (float, int) and math.isfinite(value) and lower <= value <= upper:
        return value
    return None


def date(value, pattern):
    if isinstance(value, str) and re.fullmatch(pattern, value):
        return value
    raise ValueError("Unexpected forecast date")


def optional_time(values):
    value = values[0] if values else None
    return value[11:] if isinstance(value, str) and re.fullmatch(TIME_PATTERN, value) else None


def forecast(latitude, longitude):
    if number(latitude, -90, 90) is None or number(longitude, -180, 180) is None:
        raise ValueError("Invalid coordinates")
    data = request("api.open-meteo.com", "forecast", {
        "latitude": latitude, "longitude": longitude, "current": CONDITIONS,
        "hourly": HOURLY, "forecast_hours": 25, "daily": DAILY,
        "forecast_days": 5, "timezone": "auto",
    })
    current = data["current"]
    daily = data["daily"]
    hourly = data["hourly"]
    temperature = number(current.get("temperature_2m"), -110, 80)
    if temperature is None:
        raise ValueError("Temperature unavailable")
    days = []
    for index, day in enumerate(daily["time"][:5]):
        days.append({
            "date": date(day, DAY_PATTERN),
            "code": number(daily["weather_code"][index], 0, 99),
            "high": number(daily["temperature_2m_max"][index], -110, 80),
            "low": number(daily["temperature_2m_min"][index], -110, 80),
            "rain": number(daily["precipitation_probability_max"][index], 0, 100),
        })
    hours = []
    # forecast_hours starts at the current local hour. The next entry is the
    # first forecast after the current conditions shown in the summary.
    for index, stamp in enumerate(hourly["time"][1:25], start=1):
        hours.append({
            "time": date(stamp, TIME_PATTERN),
            "temperature": number(hourly["temperature_2m"][index], -110, 80),
            "code": number(hourly["weather_code"][index], 0, 99),
            "night": hourly["is_day"][index] == 0,
            "rain": number(hourly["precipitation_probability"][index], 0, 100),
        })
    return {
        "temperature": temperature,
        "feels": number(current.get("apparent_temperature"), -130, 100),
        "humidity": number(current.get("relative_humidity_2m"), 0, 100),
        "wind": number(current.get("wind_speed_10m"), 0, 500),
        "code": number(current.get("weather_code"), 0, 99),
        "night": current.get("is_day") == 0,
        "time": date(current["time"], TIME_PATTERN),
        "gusts": number(current.get("wind_gusts_10m"), 0, 500),
        "pressure": number(current.get("pressure_msl"), 800, 1150),
        "clouds": number(current.get("cloud_cover"), 0, 100),
        "visibility": number(current.get("visibility"), 0, 200000),
        "sunrise": optional_time(daily.get("sunrise")),
        "sunset": optional_time(daily.get("sunset")),
        "uv": number(next(iter(daily.get("uv_index_max") or []), None), 0, 35),
        "rainTotal": number(next(iter(daily.get("precipitation_sum") or []), None), 0, 2000),
        "hours": hours,
        "days": days,
    }


def label(value):
    return value.strip()[:80] if isinstance(value, str) else ""


def search(query, language):
    query = query.strip()
    if not 2 <= len(query) <= 80:
        raise ValueError("Invalid city query")
    response = request("geocoding-api.open-meteo.com", "search", {
        "name": query, "count": 5, "language": "es" if language == "es" else "en",
    })
    places = []
    for row in response.get("results", [])[:5]:
        name = label(row.get("name"))
        latitude = number(row.get("latitude"), -90, 90)
        longitude = number(row.get("longitude"), -180, 180)
        if name and latitude is not None and longitude is not None:
            region = ", ".join(filter(None, [label(row.get("admin1")), label(row.get("country"))]))
            places.append({"name": name, "region": region, "lat": latitude, "lon": longitude})
    return places


if __name__ == "__main__":
    try:
        operation, first, second = sys.argv[1:]
        if operation == "forecast":
            result = forecast(float(first), float(second))
        elif operation == "search":
            result = search(first, second)
        else:
            raise ValueError("Invalid operation")
        print(json.dumps(result, allow_nan=False))
    except (ValueError, TypeError, KeyError, IndexError, OSError, subprocess.SubprocessError) as error:
        print(f"OmaWeather: {error}", file=sys.stderr)
        sys.exit(1)
