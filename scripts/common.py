"""Shared HTTP and caching utilities for data fetchers."""

import hashlib
import json
import time
from pathlib import Path

import requests

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
REGISTRY_PATH = DATA_DIR / "registry.toml"

# BFS STAT-TAB PxWeb API base
BFS_PXWEB_BASE = "https://www.pxweb.bfs.admin.ch/api/v1"

# Cache downloaded files for 24 hours
CACHE_MAX_AGE = 86400


def ensure_dirs():
    """Create data directories if they don't exist."""
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)


def cache_path(url: str, suffix: str = ".json") -> Path:
    """Return a cache file path based on URL hash."""
    h = hashlib.sha256(url.encode()).hexdigest()[:12]
    return RAW_DIR / f"{h}{suffix}"


def is_fresh(path: Path) -> bool:
    """Check if a cached file exists and is younger than CACHE_MAX_AGE."""
    if not path.exists():
        return False
    age = time.time() - path.stat().st_mtime
    return age < CACHE_MAX_AGE


def fetch_json(url: str, method: str = "GET", body: dict | None = None) -> dict:
    """Fetch JSON from a URL with file-based caching."""
    cached = cache_path(url)
    if method == "GET" and is_fresh(cached):
        return json.loads(cached.read_text())

    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if method == "POST" and body is not None:
        resp = requests.post(url, json=body, headers=headers, timeout=60)
    else:
        resp = requests.get(url, headers=headers, timeout=60)
    resp.raise_for_status()
    data = resp.json()

    cached.write_text(json.dumps(data, ensure_ascii=False, indent=2))
    return data


def pxweb_query(table_url: str, query: dict) -> dict:
    """Execute a PxWeb API query and return the JSON-stat response.

    Args:
        table_url: Full URL to the PxWeb table endpoint.
        query: PxWeb query dict with 'query' and 'response' keys.
    """
    return fetch_json(table_url, method="POST", body=query)
