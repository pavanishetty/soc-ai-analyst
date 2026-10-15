import logging
import os
from typing import Annotated

from dotenv import load_dotenv
from fastapi import Depends, FastAPI

from app.guards import looks_like_injection
from app.llm import AnthropicClient, LLMClient, OpenAIClient
from app.models import Alert, Severity, Verdict
from app.rules import apply_rules

load_dotenv()
logger = logging.getLogger("soc_ai_analyst")

app = FastAPI(title="SOC AI Analyst")


def get_llm_client() -> LLMClient | None:
    provider = os.getenv("LLM_PROVIDER", "anthropic").lower()

    if provider == "anthropic":
        key = os.getenv("ANTHROPIC_API_KEY")
        if key:
            return AnthropicClient(key, os.getenv("ANTHROPIC_MODEL", "claude-haiku-5-5"))

    if provider == "openai":
        key = os.getenv("OPENAI_API_KEY")
        if key:
            return OpenAIClient(key, os.getenv("OPENAI_MODEL", "gpt-4o-mini"))

    return None


def escalate(reason: str) -> Verdict:
    return Verdict(
        severity=Severity.medium,
        mitre_technique=None,
        explanation=reason,
        recommended_action="Escalate to an analyst.",
        decided_by="fallback",
    )


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/triage", response_model=Verdict)
def triage(alert: Alert, llm: Annotated[LLMClient | None, Depends(get_llm_client)]) -> Verdict:
    text_fields = " ".join([alert.source, alert.event_type, alert.user or "", alert.message])
    if looks_like_injection(text_fields):
        return Verdict(
            severity=Severity.high,
            mitre_technique=None,
            explanation="Alert contains text that looks like a prompt-injection attempt.",
            recommended_action="Escalate to an analyst and treat the source as hostile.",
            decided_by="guard",
        )

    verdict = apply_rules(alert)
    if verdict:
        return verdict

    if llm is None:
        return escalate("No rule matched and no LLM is configured.")

    try:
        return llm.triage(alert)
    except Exception as e:  # noqa: BLE001 - fail-safe boundary: any LLM failure must escalate, never crash
        logger.warning("LLM triage failed: %s", type(e).__name__)
        return escalate("LLM call failed or returned an invalid response.")