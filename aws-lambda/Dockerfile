FROM oraclelinux:9-slim

ARG TARGETARCH
ARG TRUFFLERUBY_VERSION=34.0.1

RUN microdnf install -y \
      ca-certificates curl gzip tar xz \
      gcc gcc-c++ make pkgconf-pkg-config \
      zlib-devel libxml2-devel libxslt-devel openssl-devel libyaml-devel libffi-devel \
    && microdnf clean all

RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) \
        TR_ARCH=amd64; \
        TR_SHA256=d73540e36d457555d57c7bff7c35805d05388912fb54a880dea10cc44d001f41 ;; \
      arm64) \
        TR_ARCH=aarch64; \
        TR_SHA256=8b1156eda10f3a00c56544f91c3f06735db49fe5850d801bb2760ab0b8315441 ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    URL="https://github.com/truffleruby/truffleruby/releases/download/graal-${TRUFFLERUBY_VERSION}/truffleruby-community-${TRUFFLERUBY_VERSION}-linux-${TR_ARCH}.tar.gz"; \
    curl --fail --location --retry 3 --output /tmp/truffleruby.tar.gz "$URL"; \
    echo "${TR_SHA256}  /tmp/truffleruby.tar.gz" | sha256sum -c -; \
    mkdir -p /opt/truffleruby; \
    tar -xzf /tmp/truffleruby.tar.gz --strip-components=1 -C /opt/truffleruby; \
    rm -f /tmp/truffleruby.tar.gz; \
    /opt/truffleruby/lib/truffle/post_install_hook.sh

ENV PATH=/opt/truffleruby/bin:${PATH} \
    BUNDLE_PATH=/opt/ores-ror-bundle \
    BUNDLE_GEMFILE=/var/task/Gemfile \
    RAILS_ENV=production \
    RACK_ENV=production \
    RAILS_LOG_TO_STDOUT=1

WORKDIR /var/task

COPY Gemfile ./Gemfile
RUN truffleruby --version \
    && bundle config set build.nokogiri --use-system-libraries \
    && bundle install --jobs 4 --retry 3

COPY . /var/task
RUN mkdir -p /var/runtime \
    && cp /var/task/aws-lambda/bootstrap /var/runtime/bootstrap \
    && chmod 0755 /var/runtime/bootstrap

ENTRYPOINT ["/var/runtime/bootstrap"]
