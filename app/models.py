from enum import Enum
from ipaddress import IPv4Address, IPv6Address

from pydantic import BaseModel, Field


class Severity(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class Alert(BaseModel):
    source: str = Field(..., max_length=100)
    event_type: str = Field(..., max_length=100)
    user: str | None = Field(None, max_length=100)
    src_ip: IPv4Address | IPv6Address | None = None
    message: str = Field(..., max_length=2000)
    count: int = Field(1, ge=1, le=100000)


class Verdict(BaseModel):
    severity: Severity
    mitre_technique: str | None
    explanation: str
    recommended_action: str
    decided_by: str