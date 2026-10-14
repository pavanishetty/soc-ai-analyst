import re

INJECTION_PATTERNS = [
    r"ignore (all |any )?(previous|prior|above) instructions",
    r"disregard (the |your )?(system|previous) prompt",
    r"you are now",
    r"mark (this|it) as (benign|low|safe)",
    r"system prompt",
]


def looks_like_injection(text: str) -> bool:
    lowered = text.lower()
    return any(re.search(pattern, lowered) for pattern in INJECTION_PATTERNS)