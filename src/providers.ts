// Replaces src/providers.ts of storage-bench. The upstream file knows ten hosted providers. This one knows any
// S3 endpoint, read from the environment. The rest of the benchmark (src/bench.ts, src/report.ts) is upstream's.
//
// One target per TARGET_<NAME>_ENDPOINT. For each name:
//   TARGET_<NAME>_ENDPOINT           https://s3.example.com
//   TARGET_<NAME>_BUCKET             an existing bucket that the benchmark can write to
//   TARGET_<NAME>_ACCESS_KEY_ID
//   TARGET_<NAME>_SECRET_ACCESS_KEY
//   TARGET_<NAME>_REGION             optional, default us-east-1 (set the real region for Amazon S3)
//   TARGET_<NAME>_LABEL              optional, a readable name, default <NAME>
//   TARGET_<NAME>_PATH_STYLE         optional, true for https://endpoint/bucket/key instead of https://bucket.endpoint/key
// The provider id in the results is <NAME> in lower case, with "_" written as "-".
import { Files } from "files-sdk";
import { s3 } from "files-sdk/s3";

export type ProviderId = string;

export type Provider = {
  readonly id: ProviderId;
  readonly label: string;
  /** Where the bucket lives, as the provider names it. */
  readonly region: string;
  /** Builds a fresh client. Each call opens new connections, which is what the cold-start test relies on. */
  readonly connect: () => Files;
  /** Largest object the account's plan accepts, when the plan caps it. Bigger sizes are skipped, not failed. */
  readonly maxObjectBytes?: number;
  /** False when the provider can't list by prefix, so the listing test is skipped rather than failed. */
  readonly canList?: false;
};

type Env = Record<string, string | undefined>;

export const isProviderId = (value: string): value is ProviderId => /^[a-z0-9][a-z0-9-]*$/.test(value);

const truthy = (value: string | undefined): boolean => /^(1|true|yes)$/i.test(value ?? "");

const target = (name: string, env: Env): Provider => {
  const get = (key: string): string | undefined => env[`TARGET_${name}_${key}`];
  const need = (key: string): string => {
    const value = get(key);
    if (value === undefined || value === "") throw new Error(`TARGET_${name}_${key} is not set`);
    return value;
  };
  const id = name.toLowerCase().replace(/_/g, "-");
  if (!isProviderId(id)) throw new Error(`TARGET_${name}: the name must be letters, digits, and underscores`);
  const endpoint = need("ENDPOINT");
  const bucket = need("BUCKET");
  const region = get("REGION") || "us-east-1";
  const credentials = { accessKeyId: need("ACCESS_KEY_ID"), secretAccessKey: need("SECRET_ACCESS_KEY") };
  const forcePathStyle = truthy(get("PATH_STYLE"));
  return {
    id,
    label: get("LABEL") || name,
    region,
    connect: () => new Files({ retries: 0, adapter: s3({ bucket, region, endpoint, forcePathStyle, credentials }) }),
  };
};

const targetNames = (env: Env): string[] =>
  Object.keys(env)
    .flatMap((key) => {
      const m = /^TARGET_(.+)_ENDPOINT$/.exec(key);
      return m?.[1] === undefined ? [] : [m[1]];
    })
    .sort();

/** Targets that are configured, optionally narrowed to `only`. */
export const loadProviders = ({ env, only }: { env: Env; only: readonly ProviderId[] | undefined }): Provider[] =>
  targetNames(env)
    .map((name) => target(name, env))
    .filter((p) => only === undefined || only.includes(p.id));
