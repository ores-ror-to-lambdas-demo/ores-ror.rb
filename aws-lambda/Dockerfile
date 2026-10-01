FROM ghcr.io/graalvm/truffleruby-community:25.0.0

WORKDIR /var/task
ENV BUNDLE_PATH=/opt/ores-ror-bundle \
    BUNDLE_GEMFILE=/var/task/Gemfile \
    RAILS_ENV=production \
    RACK_ENV=production \
    RAILS_LOG_TO_STDOUT=1

COPY Gemfile ./Gemfile
RUN bundle install --jobs 4 --retry 3

COPY . /var/task
RUN mkdir -p /var/runtime && \
    cp /var/task/aws-lambda/bootstrap /var/runtime/bootstrap && \
    chmod 0755 /var/runtime/bootstrap

ENTRYPOINT ["/var/runtime/bootstrap"]
