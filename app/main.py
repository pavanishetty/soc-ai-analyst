from fastapi import FastAPI

from app.models import Alert, Severity, Verdict
from app.rules import apply_rules

app = FastAPI(title="SOC AI Analyst")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/triage", response_model=Verdict)
def triage(alert: Alert) -> Verdict:
    verdict = apply_rules(alert)
    if verdict:
        return verdict

    # Step 2: unmatched alerts will go to the LLM here
    return Verdict(
        severity=Severity.medium,
        mitre_technique=None,
        explanation="No rule matched.",
        recommended_action="Escalate to an analyst.",
        decided_by="fallback",
    )