# s3-storage-bench

Measure the latency and the throughput of an S3 endpoint from the place where your application runs.

This repository packages [storage-bench](https://github.com/opencoredev/storage-bench) by Leo ([@leodev](https://x.com/leodev)) as a Docker image and a cloud-init file. storage-bench runs the operations that applications do: upload, download, head, list, copy, delete, range get, and signed URL. It reports the median, the p95, and the p99 for each operation and each object size.

## What you get

- A Docker image that runs storage-bench against the endpoint that you name in environment variables.
- A cloud-init file that starts the image on a new virtual machine, uploads the results to a bucket, and shuts the machine down.
- A script that creates such machines in several cities on Exoscale, waits for the results, and deletes the machines.

The image and the cloud-init file work with any S3 endpoint, hosted or in your own rack. The cloud-init file works on every cloud that accepts cloud-init. The Exoscale script is an example. A script for another cloud is a few lines and a welcome pull request.

## Status

The repository is new. The image, the cloud-init file, and the script follow in the next commits.

## Credits

storage-bench is the work of Leo ([@leodev](https://x.com/leodev)). It is published under the ISC license, as declared in its `package.json`. This repository clones it at a pinned commit when the image is built, and it does not change the tool.

## License

ISC. See [LICENSE](LICENSE).
