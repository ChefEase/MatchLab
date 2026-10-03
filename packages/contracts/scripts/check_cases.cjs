const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { validateContract } = require("../dist/validate.js");

const root = path.join(__dirname, "..");
const catalog = JSON.parse(fs.readFileSync(path.join(root, "schemas/v1.json"), "utf8"));
const cases = JSON.parse(fs.readFileSync(path.join(root, "examples/v1_cases.json"), "utf8"));

for (const [name, sample] of Object.entries(cases.samples)) {
  assert.deepEqual(validateContract(catalog, name, sample), [], `${name} should pass`);
}
for (const testCase of cases.negative_cases) {
  const sample = structuredClone(cases.samples[testCase.contract]);
  Object.assign(sample, testCase.set);
  assert.notDeepEqual(validateContract(catalog, testCase.contract, sample), [], `${testCase.name} should fail`);
}

console.log(
  `TypeScript contracts OK: ${Object.keys(cases.samples).length} valid, ${cases.negative_cases.length} invalid`,
);
