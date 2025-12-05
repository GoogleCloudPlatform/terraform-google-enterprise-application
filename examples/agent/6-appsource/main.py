# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os

import uvicorn
from fastapi import FastAPI
from google.adk.cli.fast_api import get_fast_api_app
from fastapi.responses import PlainTextResponse
import logging

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(name)s - %(message)s'
)

# Get the directory where main.py is located
AGENT_DIR = os.path.dirname(os.path.abspath(__file__))
# Example session service URI (e.g., SQLite)
SESSION_SERVICE_URI = ""
# Example allowed origins for CORS
ALLOWED_ORIGINS = ["http://localhost", "http://localhost:8080", "*"]
# Set web=True if you intend to serve a web interface, False otherwise
SERVE_WEB_INTERFACE = True

# Call the function to get the FastAPI app instance
# Ensure the agent directory name ('capital_agent') matches your agent folder
app: FastAPI = get_fast_api_app(
    agents_dir=AGENT_DIR,
    session_service_uri=SESSION_SERVICE_URI,
    allow_origins=ALLOWED_ORIGINS,
    web=SERVE_WEB_INTERFACE,
    trace_to_cloud=True,
)


@app.get("/health", include_in_schema=False)
async def health() -> PlainTextResponse:
    return PlainTextResponse("ok", status_code=200)


@app.get("/ready", include_in_schema=False)
async def ready() -> PlainTextResponse:
    return PlainTextResponse("ready", status_code=200)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
