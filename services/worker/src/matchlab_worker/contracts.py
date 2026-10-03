"""Validate MatchLab v1 payloads against the shared contract catalog.

The catalog is passed in by the caller so the web and worker can consume the
same versioned JSON file without copying schema definitions into Python.
"""

import math
import re
from datetime import datetime
from typing import Any


SUPPORTED = {
    "type", "required", "additionalProperties", "properties", "items", "enum", "const",
    "pattern", "minLength", "maxLength", "minimum", "maximum", "minItems", "maxItems", "format",
}
UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", re.I)
DATE_TIME = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"
)


def _matches_type(value: Any, kind: str) -> bool:
    if kind == "object":
        return isinstance(value, dict)
    if kind == "array":
        return isinstance(value, list)
    if kind == "integer":
        return isinstance(value, int) and not isinstance(value, bool) and abs(value) <= 2**53 - 1
    if kind == "number":
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return False
        return abs(value) <= 2**53 - 1 if isinstance(value, int) else math.isfinite(value)
    if kind == "string":
        return isinstance(value, str)
    if kind == "boolean":
        return isinstance(value, bool)
    if kind == "null":
        return value is None
    raise ValueError(f"Unsupported contract type: {kind}")


def _same_primitive(left: Any, right: Any) -> bool:
    if isinstance(left, bool) != isinstance(right, bool):
        return False
    return left == right


def _check(schema: dict[str, Any], value: Any, path: str, errors: list[str]) -> None:
    unknown = set(schema) - SUPPORTED
    if unknown:
        raise ValueError(f"Unsupported contract keyword: {sorted(unknown)[0]}")
    allowed_types = schema.get("type")
    if allowed_types is not None:
        kinds = allowed_types if isinstance(allowed_types, list) else [allowed_types]
        if not any(_matches_type(value, kind) for kind in kinds):
            errors.append(f"{path}: type")
            return
    if "const" in schema and not _same_primitive(value, schema["const"]):
        errors.append(f"{path}: const")
    if "enum" in schema and not any(_same_primitive(value, item) for item in schema["enum"]):
        errors.append(f"{path}: enum")

    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            errors.append(f"{path}: minLength")
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            errors.append(f"{path}: maxLength")
        if "pattern" in schema and not re.search(schema["pattern"], value):
            errors.append(f"{path}: pattern")
        if schema.get("format") == "uuid" and not UUID.fullmatch(value):
            errors.append(f"{path}: uuid")
        if schema.get("format") == "date-time":
            try:
                if not DATE_TIME.fullmatch(value):
                    raise ValueError("invalid timestamp format")
                datetime.fromisoformat(value.replace("Z", "+00:00"))
            except ValueError:
                errors.append(f"{path}: date-time")
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path}: minimum")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path}: maximum")
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            errors.append(f"{path}: minItems")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{path}: maxItems")
        if isinstance(schema.get("items"), dict):
            for index, item in enumerate(value):
                _check(schema["items"], item, f"{path}[{index}]", errors)
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path}.{key}: required")
        for key, item in value.items():
            if key not in properties:
                if schema.get("additionalProperties") is False:
                    errors.append(f"{path}.{key}: additionalProperties")
            elif isinstance(properties[key], dict):
                _check(properties[key], item, f"{path}.{key}", errors)


def validate_contract(catalog: dict[str, Any], name: str, payload: Any) -> list[str]:
    """Return validation errors, or an empty list when the payload matches v1."""
    try:
        schema = catalog["$defs"][name]
    except KeyError as exc:
        raise ValueError(f"Unknown contract: {name}") from exc
    errors: list[str] = []
    _check(schema, payload, name, errors)
    return errors


def assert_contract(catalog: dict[str, Any], name: str, payload: Any) -> None:
    errors = validate_contract(catalog, name, payload)
    if errors:
        raise ValueError(f"Invalid {name}: {', '.join(errors)}")
