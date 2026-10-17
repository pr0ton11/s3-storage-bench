// Uploads the results directory to an S3 bucket, so a runner needs no inbound access and can be deleted after the run.
//   RESULTS_ENDPOINT, RESULTS_BUCKET, RESULTS_ACCESS_KEY_ID, RESULTS_SECRET_ACCESS_KEY   required
//   RESULTS_REGION (default us-east-1), RESULTS_PREFIX (default results), RESULTS_PATH_STYLE (true for path style)
// Objects are stored as <prefix>/<client>/<path under the results directory>.
import { readdir, readFile } from "node:fs/promises";
import { join, relative } from "node:path";
import { parseArgs } from "node:util";
import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";

const args = parseArgs({ options: { dir: { type: "string", default: "/results" }, client: { type: "string", default: "local" } } });

const env = process.env;
const need = (key: string): string => {
  const value = env[key];
  if (value === undefined || value === "") throw new Error(`${key} is not set`);
  return value;
};

const client = new S3Client({
  endpoint: need("RESULTS_ENDPOINT"),
  region: env.RESULTS_REGION || "us-east-1",
  forcePathStyle: /^(1|true|yes)$/i.test(env.RESULTS_PATH_STYLE ?? ""),
  credentials: { accessKeyId: need("RESULTS_ACCESS_KEY_ID"), secretAccessKey: need("RESULTS_SECRET_ACCESS_KEY") },
  // S3-compatible services differ in which checksum headers they accept. Send them only when an operation needs them.
  requestChecksumCalculation: "WHEN_REQUIRED",
  responseChecksumValidation: "WHEN_REQUIRED",
});
const bucket = need("RESULTS_BUCKET");
const prefix = (env.RESULTS_PREFIX || "results").replace(/\/+$/, "");

const files = (await readdir(args.values.dir, { recursive: true, withFileTypes: true }))
  .filter((entry) => entry.isFile())
  .map((entry) => join(entry.parentPath, entry.name));

for (const file of files) {
  const key = `${prefix}/${args.values.client}/${relative(args.values.dir, file)}`;
  await client.send(new PutObjectCommand({ Bucket: bucket, Key: key, Body: await readFile(file) }));
  process.stderr.write(`uploaded s3://${bucket}/${key}\n`);
}
