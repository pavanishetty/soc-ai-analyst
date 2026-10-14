from app.models import Alert, Severity, Verdict


def apply_rules(alert: Alert) -> Verdict | None:
    msg = alert.message.lower()

    if alert.event_type == "failed_login" and alert.count >= 20:
        return Verdict(
            severity=Severity.high,
            mitre_technique="T1110 - Brute Force",
            explanation=f"{alert.count} failed logins from {alert.src_ip}.",
            recommended_action="Block the source IP and check for a later successful login.",
            decided_by="rules",
        )

    if alert.event_type == "process_execution" and "powershell" in msg and "-enc" in msg:
        return Verdict(
            severity=Severity.high,
            mitre_technique="T1059.001 - PowerShell",
            explanation="Encoded PowerShell command, commonly used to hide malicious scripts.",
            recommended_action="Isolate the host and decode the command for review.",
            decided_by="rules",
        )

    return None