from __future__ import annotations

import json
import logging
import os
import time
import uuid
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException, Request, Response
from nemoguardrails import LLMRails, RailsConfig


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("owasp-guardrail-gateway")

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/")
CONFIG_DIR = os.getenv("NEMO_CONFIG_DIR", "/opt/owasp-guardrail-gateway/config")
PRESIDIO_ENABLED = os.getenv("PRESIDIO_ENABLED", "false").lower() == "true"

rails = LLMRails(RailsConfig.from_path(CONFIG_DIR))
client = httpx.AsyncClient(timeout=httpx.Timeout(300.0, connect=10.0))
analyzer = None
anonymizer = None

if PRESIDIO_ENABLED:
    from presidio_analyzer import AnalyzerEngine
    from presidio_anonymizer import AnonymizerEngine

    analyzer = AnalyzerEngine()
    anonymizer = AnonymizerEngine()

app = FastAPI(title="OWASP NeMo Guardrails Gateway", version="1.0.0")


def _content(response: Any) -> str:
    if isinstance(response, dict):
        return str(response.get("content", ""))
    content = getattr(response, "content", None)
    if content is not None:
        return str(content)
    return str(response)


def _redact(text: str) -> tuple[str, int]:
    if not PRESIDIO_ENABLED or not text or analyzer is None or anonymizer is None:
        return text, 0
    findings = analyzer.analyze(text=text, language="en")
    if not findings:
        return text, 0
    return anonymizer.anonymize(text=text, analyzer_results=findings).text, len(findings)


def _redact_messages(messages: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], int]:
    result: list[dict[str, Any]] = []
    total = 0
    for message in messages:
        copied = dict(message)
        if isinstance(copied.get("content"), str):
            copied["content"], count = _redact(copied["content"])
            total += count
        result.append(copied)
    return result, total


@app.get("/healthz")
async def healthz() -> dict[str, Any]:
    response = await client.get(f"{OLLAMA_URL}/api/tags")
    response.raise_for_status()
    return {
        "status": "ok",
        "path": ["presidio", "nemo", "ollama"] if PRESIDIO_ENABLED else ["nemo", "ollama"],
        "presidio_enabled": PRESIDIO_ENABLED,
    }


@app.post("/api/chat")
async def chat(request: Request, response: Response) -> dict[str, Any]:
    payload = await request.json()
    if payload.get("stream") is True:
        raise HTTPException(status_code=400, detail="stream=true is not enabled for this lab gateway")

    messages = payload.get("messages")
    if not isinstance(messages, list) or not messages:
        raise HTTPException(status_code=422, detail="messages must be a non-empty list")

    request_id = str(uuid.uuid4())
    started = time.monotonic()
    guarded_messages, input_findings = _redact_messages(messages)

    if payload.get("format"):
        guarded_messages = list(guarded_messages)
        guarded_messages.insert(
            0,
            {
                "role": "system",
                "content": "Return only JSON conforming to this schema: " + json.dumps(payload["format"]),
            },
        )

    result = await rails.generate_async(messages=guarded_messages)
    text = _content(result)
    text, output_findings = _redact(text)
    elapsed_ms = round((time.monotonic() - started) * 1000)
    path = "presidio>nemo>ollama>presidio" if PRESIDIO_ENABLED else "nemo>ollama"
    response.headers["X-Guardrail-Path"] = path
    response.headers["X-Guardrail-Request-Id"] = request_id
    log.info(
        "request_id=%s endpoint=/api/chat path=%s input_pii=%d output_pii=%d elapsed_ms=%d",
        request_id,
        path,
        input_findings,
        output_findings,
        elapsed_ms,
    )
    return {
        "model": payload.get("model", "guarded-ollama"),
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "message": {"role": "assistant", "content": text},
        "done": True,
        "done_reason": "stop",
        "guardrail": {
            "request_id": request_id,
            "path": path,
            "input_pii_findings": input_findings,
            "output_pii_findings": output_findings,
        },
    }


@app.post("/api/generate")
async def generate(request: Request, response: Response) -> dict[str, Any]:
    payload = await request.json()
    prompt = str(payload.get("prompt", ""))
    guarded_prompt, input_findings = _redact(prompt)
    result = await rails.generate_async(messages=[{"role": "user", "content": guarded_prompt}])
    text, output_findings = _redact(_content(result))
    path = "presidio>nemo>ollama>presidio" if PRESIDIO_ENABLED else "nemo>ollama"
    response.headers["X-Guardrail-Path"] = path
    return {
        "model": payload.get("model", "guarded-ollama"),
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "response": text,
        "done": True,
        "done_reason": "stop",
        "guardrail": {
            "path": path,
            "input_pii_findings": input_findings,
            "output_pii_findings": output_findings,
        },
    }


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def ollama_compatibility_proxy(path: str, request: Request, response: Response) -> Response:
    upstream = await client.request(
        request.method,
        f"{OLLAMA_URL}/{path}",
        content=await request.body(),
        headers={"content-type": request.headers.get("content-type", "application/json")},
    )
    log.info("endpoint=/%s path=gateway>ollama status=%d", path, upstream.status_code)
    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        media_type=upstream.headers.get("content-type"),
        headers={"X-Guardrail-Path": "gateway>ollama"},
    )
