/** Dependency-free validator for the JSON Schema keywords used by v1.json. */
export type ContractName =
  "fixture" | "evidence_snapshot" | "job_request" | "job_status" | "forecast_report" | "scenario" | "api_error";

type Schema = Record<string, unknown>;
type Catalog = { $defs: Record<string, Schema> };

const supported = new Set([
  "type",
  "required",
  "additionalProperties",
  "properties",
  "items",
  "enum",
  "const",
  "pattern",
  "minLength",
  "maxLength",
  "minimum",
  "maximum",
  "minItems",
  "maxItems",
  "format",
]);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const dateTime = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-](\d{2}):(\d{2}))$/;

function validDateTime(value: string): boolean {
  const match = dateTime.exec(value);
  if (!match) return false;
  const [, yearText, monthText, dayText, hourText, minuteText, secondText, offsetHour, offsetMinute] = match;
  const [year, month, day, hour, minute, second] = [yearText, monthText, dayText, hourText, minuteText, secondText].map(
    Number,
  );
  if (year < 1 || month < 1 || month > 12 || hour > 23 || minute > 59 || second > 59) return false;
  if (offsetHour !== undefined && (Number(offsetHour) > 23 || Number(offsetMinute) > 59)) return false;
  const leap = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return day >= 1 && day <= days[month - 1];
}

function record(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function matchesType(value: unknown, type: string): boolean {
  if (type === "object") return record(value);
  if (type === "array") return Array.isArray(value);
  if (type === "integer") return typeof value === "number" && Number.isSafeInteger(value);
  if (type === "number") return typeof value === "number" && Number.isFinite(value);
  if (type === "null") return value === null;
  if (["string", "boolean"].includes(type)) return typeof value === type;
  throw new Error(`Unsupported contract type: ${type}`);
}

function check(schema: Schema, value: unknown, path: string, errors: string[]): void {
  for (const key of Object.keys(schema)) {
    if (!supported.has(key)) throw new Error(`Unsupported contract keyword: ${key}`);
  }
  const allowedTypes = schema.type === undefined ? undefined : Array.isArray(schema.type) ? schema.type : [schema.type];
  if (allowedTypes && !allowedTypes.some((type) => matchesType(value, String(type)))) {
    errors.push(`${path}: type`);
    return;
  }
  if (schema.const !== undefined && value !== schema.const) errors.push(`${path}: const`);
  if (Array.isArray(schema.enum) && !schema.enum.includes(value)) errors.push(`${path}: enum`);

  if (typeof value === "string") {
    if (typeof schema.minLength === "number" && value.length < schema.minLength) errors.push(`${path}: minLength`);
    if (typeof schema.maxLength === "number" && value.length > schema.maxLength) errors.push(`${path}: maxLength`);
    if (typeof schema.pattern === "string" && !new RegExp(schema.pattern).test(value)) errors.push(`${path}: pattern`);
    if (schema.format === "uuid" && !uuid.test(value)) errors.push(`${path}: uuid`);
    if (schema.format === "date-time" && !validDateTime(value)) {
      errors.push(`${path}: date-time`);
    }
  }
  if (typeof value === "number") {
    if (typeof schema.minimum === "number" && value < schema.minimum) errors.push(`${path}: minimum`);
    if (typeof schema.maximum === "number" && value > schema.maximum) errors.push(`${path}: maximum`);
  }
  if (Array.isArray(value)) {
    if (typeof schema.minItems === "number" && value.length < schema.minItems) errors.push(`${path}: minItems`);
    if (typeof schema.maxItems === "number" && value.length > schema.maxItems) errors.push(`${path}: maxItems`);
    if (record(schema.items))
      value.forEach((item, index) => check(schema.items as Schema, item, `${path}[${index}]`, errors));
  }
  if (record(value)) {
    const properties = record(schema.properties) ? schema.properties : {};
    const required = Array.isArray(schema.required) ? schema.required : [];
    for (const key of required) {
      if (typeof key === "string" && !Object.hasOwn(value, key)) errors.push(`${path}.${key}: required`);
    }
    for (const [key, item] of Object.entries(value)) {
      if (!Object.hasOwn(properties, key)) {
        if (schema.additionalProperties === false) errors.push(`${path}.${key}: additionalProperties`);
      } else if (record(properties[key])) {
        check(properties[key] as Schema, item, `${path}.${key}`, errors);
      }
    }
  }
}

export function validateContract(catalog: Catalog, name: ContractName, payload: unknown): string[] {
  const schema = catalog.$defs[name];
  if (!record(schema)) throw new Error(`Unknown contract: ${name}`);
  const errors: string[] = [];
  check(schema, payload, name, errors);
  return errors;
}

export function assertContract(catalog: Catalog, name: ContractName, payload: unknown): void {
  const errors = validateContract(catalog, name, payload);
  if (errors.length) throw new Error(`Invalid ${name}: ${errors.join(", ")}`);
}
