const url = process.env.MATCHLAB_WEB_HEALTH_URL ?? "http://localhost:3000/api/health";

try {
  const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
  const body = await response.json();

  if (!response.ok || body.status !== "ok" || body.service !== "web") {
    throw new Error(`Unexpected health response: ${response.status}`);
  }

  console.log(`Web health OK: ${url}`);
} catch (error) {
  console.error(`Web health failed: ${error.message}`);
  process.exitCode = 1;
}
