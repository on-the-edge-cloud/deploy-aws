import assert from "node:assert/strict";

const baseUrl = process.argv[2] ?? "http://localhost:3000";

async function request(path) {
  const response = await fetch(new URL(path, baseUrl), {
    signal: AbortSignal.timeout(30000),
  });
  assert.equal(response.status, 200, `${path}: expected HTTP 200`);
  return response;
}

function timestamp(html) {
  const match = html.match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/);
  assert.ok(match, "Expected a server-rendered timestamp");
  return match[0];
}

const firstSsr = await request("/ssr/");
assert.match(firstSsr.headers.get("cache-control") ?? "", /no-store|private/);
const firstTimestamp = timestamp(await firstSsr.text());
const secondTimestamp = timestamp(await (await request("/ssr/")).text());
assert.notEqual(firstTimestamp, secondTimestamp, "SSR must render on every request");

const healthResponse = await request("/api/health/");
assert.match(healthResponse.headers.get("cache-control") ?? "", /no-store/);
const health = await healthResponse.json();
assert.equal(health.status, "ok");
assert.ok(Number.isFinite(Date.parse(health.timestamp)));

const isrResponse = await request("/isr/");
assert.match(isrResponse.headers.get("cache-control") ?? "", /s-maxage=60/);
const firstIsr = timestamp(await isrResponse.text());
const secondIsr = timestamp(await (await request("/isr/")).text());
if (Date.now() - Date.parse(firstIsr) < 55000) {
  assert.equal(firstIsr, secondIsr, "ISR must reuse the cached page within its TTL");
}

console.log(`SSR, API and ISR cache smoke checks passed: ${baseUrl}`);