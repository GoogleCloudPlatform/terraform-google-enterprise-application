# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""OpenTelemetry helper module for the mortgage agent."""

from __future__ import annotations

import logging
import os

logger = logging.getLogger(__name__)


def setup_telemetry():
    """Setup OpenTelemetry instrumentation when running outside Agent Engine."""
    try:
        from opentelemetry import trace
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor

        provider = TracerProvider()
        trace.set_tracer_provider(provider)
        logger.info("OpenTelemetry TracerProvider configured.")
    except Exception as e:
        logger.warning("Telemetry setup skipped or failed: %s", e)
