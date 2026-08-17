# NeMo First, Then Presidio

This lab is intentionally split into two checkpoints. Complete and verify NeMo
before adding Presidio.

## Traffic path

Stage 1:

```text
OWASP app -> NeMo Guardrails gateway :11500 -> Ollama :11434
```

Stage 2:

```text
OWASP app -> Presidio input anonymization -> NeMo Guardrails
          -> Ollama -> Presidio output anonymization -> OWASP app
```

The original Ollama listener must be bound to `127.0.0.1:11434`. OWASP apps use
`http://host.containers.internal:11500`; they must not call port 11434 directly.

## Stage 1: NeMo first

1. From the project root, run
   `cd infrastructure/guardrails && sudo ./01-install-nemo.sh`.
2. Confirm `/healthz` reports `presidio_enabled: false`.
3. Start the gateway with `PRESIDIO_ENABLED=false`.
4. Change every OWASP app upstream from port 11434 to port 11500.
5. Bind Ollama to `127.0.0.1:11434`.

Verify the gateway itself:

```bash
curl -fsS http://127.0.0.1:11500/healthz | jq
curl -i -sS http://127.0.0.1:11500/api/chat \
  -H 'content-type: application/json' \
  -d '{"model":"llama3.1:8b-instruct-q4_K_M","stream":false,"messages":[{"role":"user","content":"Reply with ready"}]}'
journalctl -u owasp-guardrail-gateway -n 50 --no-pager
```

The response must contain `X-Guardrail-Path: nemo>ollama`. The journal must show
the same request ID. Verify an OWASP app request after this direct smoke test.
Do not proceed until an application request, rather than only a direct gateway
request, appears in the journal with `path=nemo>ollama`.

## Stage 2: Add Presidio

Only begin this stage after Stage 1 passes.

1. From the project root, run
   `cd infrastructure/guardrails && sudo ./02-enable-presidio.sh`. The script
   refuses to run unless the NeMo-only health check passes first.
2. Confirm `/healthz` reports `presidio_enabled: true`.
3. OWASP app settings do not change; they continue to call port 11500.

```bash
curl -i -sS http://127.0.0.1:11500/api/chat \
  -H 'content-type: application/json' \
  -d '{"model":"llama3.1:8b-instruct-q4_K_M","stream":false,"messages":[{"role":"user","content":"My email is student@example.com. Repeat it."}]}'
```

The response must contain `X-Guardrail-Path: presidio>nemo>ollama>presidio`, and
the JSON `guardrail.input_pii_findings` value must be greater than zero.

The bundled Presidio analyzer uses its English model. Add an appropriate
recognizer or NLP model before treating Korean PII detection as covered.

## Rollback

Set OWASP app upstreams back to `http://host.containers.internal:11434`, restore
Ollama's original publish binding, and then disable the gateway service. Do not
disable the gateway first, because that leaves every application without an LLM.
