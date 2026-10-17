# s3-storage-bench

Measure the latency and the throughput of any S3 endpoint from the place where your application runs.

The image packages [storage-bench](https://github.com/opencoredev/storage-bench) by Leo ([@leodev](https://x.com/leodev)). It runs the operations that applications do: upload, download, head, list, copy, delete, range get, and signed URL. It reports the median, the p95, and the p99 for each operation and each object size.

## Run it

```sh
docker build -t s3-storage-bench .
```

Copy `.env.example` to `.env`, fill in one endpoint, and run a short check:

```sh
docker run --rm --env-file .env s3-storage-bench
```

If the check passes, set `PROFILE=full` and run it again. A full pass against one endpoint takes 10 to 30 minutes. The results are in `/results` inside the container. Mount a directory there to keep them:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD/results:/results" --env-file .env s3-storage-bench
```

Or set the `RESULTS_*` variables to upload them to a bucket.

## Run it from Exoscale

With the [Exoscale CLI](https://github.com/exoscale/cli) signed in and `RESULTS_*` set in `.env`:

```sh
exoscale/run.sh ch-gva-2 de-fra-1 at-vie-1
```

It starts one instance per zone, which builds the image from the pushed commit, runs the profile set in `.env`, uploads the results, and powers off. The script deletes each instance when it has stopped. The client name in the results is `exo-<zone>`.

`RESULTS_*` must be set, because the instance is deleted after the run. When the results endpoint is Exoscale object storage, `https://sos-<zone>.exo.io`, the script creates the bucket when it is missing and downloads the results of the run to `results/<stamp>/`. Use a key that may use object storage only for the results, because the instance holds it.

## Configuration

One block of `TARGET_<NAME>_*` variables describes one endpoint. The name becomes the provider id in the results, in lower case. Several endpoints run interleaved in one pass.

| Variable | Required | Meaning |
|---|---|---|
| `TARGET_<NAME>_ENDPOINT` | yes | The URL of the S3 endpoint. |
| `TARGET_<NAME>_BUCKET` | yes | An existing bucket that the benchmark can write to. |
| `TARGET_<NAME>_ACCESS_KEY_ID` | yes | The access key. |
| `TARGET_<NAME>_SECRET_ACCESS_KEY` | yes | The secret key. |
| `TARGET_<NAME>_REGION` | no | The region for the signature. The default is `us-east-1`. Set the real region for Amazon S3. |
| `TARGET_<NAME>_LABEL` | no | A readable name. The default is the name. |
| `TARGET_<NAME>_PATH_STYLE` | no | `true` for `https://endpoint/bucket/key`. The default is `https://bucket.endpoint/key`. |
| `CLIENT` | no | The name of the machine in the results. The default is the hostname. |
| `PROFILE` | no | `smoke` for a short check or `full` for a measurement. The default is `smoke`. |
| `PASSES` | no | How many passes to run. The default is `1`. |
| `CONCURRENCY`, `BURST` | no | Parallel uploads in the concurrency test and in the burst test. The defaults are `16` and `32`, as upstream. Lower them for an endpoint behind a network that filters bursts of new connections. The row labels follow the values. |
| `PROVIDERS` | no | A comma-separated list of provider ids. The default is every configured endpoint. |
| `RESULTS_ENDPOINT`, `RESULTS_BUCKET`, `RESULTS_ACCESS_KEY_ID`, `RESULTS_SECRET_ACCESS_KEY` | no | Where to upload the results. If `RESULTS_ENDPOINT` is empty, nothing is uploaded. |
| `RESULTS_REGION`, `RESULTS_PREFIX`, `RESULTS_PATH_STYLE` | no | As above, for the results bucket. The default prefix is `results`. |

## Results

Each pass writes `raw/<run id>.jsonl` with every sample and `raw/<run id>.meta.json` with the run. After the last pass, `RESULTS.md` and `summary.json` hold one table per client. A smoke run writes samples but no table, because storage-bench reports only full runs.

Uploaded results are stored as `<prefix>/<client>/<path>` in the results bucket.

Before the passes, `network.json` records the network round trip to each endpoint: the time of a TCP handshake, 30 times, as minimum, median, and p95. Subtract it from a small read to see what the service adds on top of the network.

The benchmark writes its own objects to the bucket and deletes them. Each run calls `ipinfo.io` once to record the region and the network of the client.

## How the image is built

The Dockerfile downloads `src/bench.ts` and `src/report.ts` of storage-bench at one pinned commit and verifies their checksums. `src/providers.ts` is replaced by a file that reads endpoints from the environment instead of ten hosted providers. The two burst sizes become the environment variables `CONCURRENCY` and `BURST` with upstream's defaults. The method, the operations, the sizes, and the profiles are otherwise unchanged. To move to a newer upstream commit, change `UPSTREAM_COMMIT` and the two checksums in the Dockerfile together.

storage-bench is published under the ISC license, as declared in its `package.json`.

## License

ISC. See [LICENSE](LICENSE).
