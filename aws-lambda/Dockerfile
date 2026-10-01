FROM ghcr.io/graalvm/truffleruby-community:25.0.2

WORKDIR /var/task
ENV BUNDLE_PATH=/opt/ores-ror-bundle \
    BUNDLE_GEMFILE=/var/task/Gemfile \
    RAILS_ENV=production \
    RACK_ENV=production \
    RAILS_LOG_TO_STDOUT=1

# TruffleRuby 34.x is carried by the Graal/Truffle 25.0.2 standalone image.
# Rails pulls Nokogiri transitively; install the small native-build toolchain
# and use the system XML libraries rather than mini_portile downloads.
RUN microdnf install -y \
      gcc gcc-c++ make xz pkgconf-pkg-config \
      libxml2-devel libxslt-devel zlib-devel \
    && microdnf clean all

COPY Gemfile ./Gemfile
RUN truffleruby --version \
    && bundle config set build.nokogiri --use-system-libraries \
    && bundle install --jobs 4 --retry 3

COPY . /var/task
RUN mkdir -p /var/runtime \
    && cp /var/task/aws-lambda/bootstrap /var/runtime/bootstrap \
    && chmod 0755 /var/runtime/bootstrap

ENTRYPOINT ["/var/runtime/bootstrap"]
