FROM ruby:3.4.6-alpine3.22@sha256:d594d5debffa14c591c4fe03b9d0d79cdc28f30d594f47be748e642746057fec
RUN apk add --no-cache \
      ca-certificates=20260909-r0 \
      git=2.49.1-r0 \
      github-cli=2.72.0-r6 \
      openssh-client-default=10.0_p1-r10 \
 && addgroup -S -g 101 shaka \
 && adduser -S -u 100 -G shaka -h /home/shaka shaka \
 && mkdir -p /home/shaka /seed/probe /workspace \
 && chown -R shaka:shaka /home/shaka /workspace

COPY --chmod=0555 probe-preflight probe-reset /usr/local/bin/
USER shaka
WORKDIR /workspace
