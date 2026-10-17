// Measures the network round trip to each target as the time of a TCP handshake, after one DNS lookup.
// It needs nothing on the server and shows how much of a request is the wire. Writes <out>:
//   [{ id, host, port, address, samples, min_ms, p50_ms, p95_ms }]
import { lookup } from "node:dns/promises";
import { writeFile } from "node:fs/promises";
import { connect } from "node:net";
import { performance } from "node:perf_hooks";
import { parseArgs } from "node:util";
import { loadProviders } from "./providers.ts";

const args = parseArgs({ options: { out: { type: "string", default: "/results/network.json" }, samples: { type: "string", default: "30" } } });
const samples = Number(args.values.samples);

const handshake = (address: string, port: number): Promise<number> =>
  new Promise((resolve, reject) => {
    const start = performance.now();
    const socket = connect({ host: address, port });
    socket.setTimeout(5000, () => socket.destroy(new Error("timeout")));
    socket.once("connect", () => {
      const ms = performance.now() - start;
      socket.destroy();
      resolve(ms);
    });
    socket.once("error", reject);
  });

const quantile = (sorted: number[], q: number): number => {
  const pos = (sorted.length - 1) * q;
  const lo = Math.floor(pos);
  const hi = Math.ceil(pos);
  return (sorted[lo] ?? NaN) + ((sorted[hi] ?? NaN) - (sorted[lo] ?? NaN)) * (pos - lo);
};
const round = (ms: number): number => Math.round(ms * 100) / 100;

const results = [];
for (const p of loadProviders({ env: process.env, only: undefined })) {
  const url = new URL(process.env[`TARGET_${p.id.toUpperCase().replace(/-/g, "_")}_ENDPOINT`] ?? "");
  const port = Number(url.port || (url.protocol === "https:" ? 443 : 80));
  const { address } = await lookup(url.hostname);
  const times: number[] = [];
  for (let i = 0; i < samples; i++) {
    times.push(await handshake(address, port));
    await new Promise((r) => setTimeout(r, 100));
  }
  times.sort((a, b) => a - b);
  const result = { id: p.id, host: url.hostname, port, address, samples, min_ms: round(times[0] ?? NaN), p50_ms: round(quantile(times, 0.5)), p95_ms: round(quantile(times, 0.95)) };
  process.stderr.write(`network ${p.id}: round trip p50 ${result.p50_ms} ms, min ${result.min_ms} ms\n`);
  results.push(result);
}
await writeFile(args.values.out, `${JSON.stringify(results, null, 2)}\n`);
