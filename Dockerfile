# syntax=docker/dockerfile:1.7
# storage-bench by Leo (https://github.com/opencoredev/storage-bench, ISC), pinned to one commit, with a provider
# file that reads any S3 endpoint from the environment. Change UPSTREAM_COMMIT and the two checksums together.
ARG NODE_IMAGE=node:24-alpine

FROM ${NODE_IMAGE} AS build
ARG UPSTREAM_COMMIT=ecfb096fdd04433ea6a8707c6ff0c07b59062287
WORKDIR /app
COPY package.json package-lock.json ./
# Optional dependencies of files-sdk are its MCP server. The benchmark does not use it.
RUN npm ci --omit=dev --omit=optional --ignore-scripts --no-audit --no-fund
ADD https://raw.githubusercontent.com/opencoredev/storage-bench/${UPSTREAM_COMMIT}/src/bench.ts src/bench.ts
ADD https://raw.githubusercontent.com/opencoredev/storage-bench/${UPSTREAM_COMMIT}/src/report.ts src/report.ts
# Checked in a RUN step, because the classic builder ignores ADD --checksum without an error.
RUN printf '%s  src/bench.ts\n%s  src/report.ts\n' \
      dddccf9cf33a812cc5bccc8add833496401501185ad53c9b6794541ad4e0eb27 \
      c4c6d98ed75eb283e23ba7348c1b1aaec1eca4e80e3831c102d920a9b7a31020 | sha256sum -c -
COPY src/providers.ts src/upload.ts src/
COPY run.sh ./
RUN chmod 644 src/*.ts package.json package-lock.json && chmod 755 run.sh

# The runtime image is Alpine plus the Node binary. No npm, no headers, no build tools.
FROM alpine:3.22
ARG UPSTREAM_COMMIT=ecfb096fdd04433ea6a8707c6ff0c07b59062287
ENV UPSTREAM_COMMIT=$UPSTREAM_COMMIT
ENV NODE_ENV=production
RUN apk add --no-cache libstdc++ libgcc && adduser -D -u 1000 bench && mkdir /results && chown bench:bench /results
COPY --from=build /usr/local/bin/node /usr/local/bin/node
COPY --from=build /app /app
WORKDIR /app
USER bench
ENTRYPOINT ["./run.sh"]
