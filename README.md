# s3-storage-bench

Measure the latency and the throughput of an S3 endpoint from the place where your application runs.

This repository packages [storage-bench](https://github.com/opencoredev/storage-bench) by Leo ([@leodev](https://x.com/leodev)) as a Docker image. storage-bench runs the operations that applications do: upload, download, head, list, copy, delete, range get, and signed URL. It reports the median, the p95, and the p99 for each operation and each object size.

The image works with any S3 endpoint, hosted or in your own rack. A cloud-init file and a script for Exoscale follow in the next commits.

## Run it

Build the image:

```sh
docker build -t s3-storage-bench .
```

Copy `.env.example` to `.env`, fill in one endpoint, and run a short check:

```sh
docker run --rm --env-file .env s3-storage-bench
```

If the check passes, set `PROFILE=full` in `.env` and run it again. A full pass against one endpoint takes 10 to 30 minutes. The results are in `/results` inside the container. Mount a directory there to keep them, and run as your own user so that the container can write to it:

```sh
mkdir -p results
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD/results:/results" --env-file .env s3-storage-bench
```

If your Docker setup maps the mount to root, use a named volume (`-v results:/results`) instead and copy the files out with `docker cp`. Or set the `RESULTS_*` variables to upload the results to a bucket. Then no mount is needed.

## Configuration

Every setting is an environment variable. One block of `TARGET_<NAME>_*` variables describes one endpoint. The name becomes the provider id in the results, in lower case. You can configure several endpoints, and the benchmark interleaves them in one run.

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
| `PROVIDERS` | no | A comma-separated list of provider ids. The default is every configured endpoint. |
| `RESULTS_ENDPOINT`, `RESULTS_BUCKET`, `RESULTS_ACCESS_KEY_ID`, `RESULTS_SECRET_ACCESS_KEY` | no | Where to upload the results. If `RESULTS_ENDPOINT` is empty, nothing is uploaded. |
| `RESULTS_REGION`, `RESULTS_PREFIX`, `RESULTS_PATH_STYLE` | no | As above, for the results bucket. The default prefix is `results`. |

## Results

Each pass writes one `raw/<run id>.jsonl` file with every sample and one `raw/<run id>.meta.json` file with the run. After the last pass, `RESULTS.md` and `summary.json` hold one table per client. A smoke run writes samples but no table, because storage-bench counts only full runs.

Uploaded results are stored as `<prefix>/<client>/<path>` in the results bucket.

The benchmark uses the bucket for its own objects and deletes them. Each run calls `ipinfo.io` once to record the region and the network of the client in the metadata. Set `TARGET_<NAME>_REGION` and the other values to match your endpoint, and do not point the benchmark at a bucket with data that you need.

## How the image is built

The Dockerfile downloads `src/bench.ts` and `src/report.ts` of storage-bench at one pinned commit and verifies their checksums. `src/providers.ts` is replaced by a file that reads endpoints from the environment. The upstream file knows ten hosted providers, and this one knows any S3 endpoint. The method, the operations, the sizes, and the profiles are unchanged. To move to a newer upstream commit, change `UPSTREAM_COMMIT` and the two checksums in the Dockerfile together.

The runtime image is Alpine with the Node 24 binary and the production dependencies. It has no npm and no shell tools beyond BusyBox.

## Credits

storage-bench is the work of Leo ([@leodev](https://x.com/leodev)). It is published under the ISC license, as declared in its `package.json`.

## License

ISC. See [LICENSE](LICENSE).
