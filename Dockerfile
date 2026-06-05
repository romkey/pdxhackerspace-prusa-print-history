# syntax=docker/dockerfile:1
# check=error=true

# Production image. Multi-stage; non-root runtime user; assets precompiled.
# Build:  docker build -t prusa-print-history .
# Run:    docker compose -f docker-compose.server.yml up -d

ARG RUBY_VERSION=3.3.11
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y curl cups-client libjemalloc2 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

FROM base AS build

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev node-gyp pkg-config python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ARG NODE_VERSION=24.10.0
ARG TARGETARCH
RUN ARCH="$(case "${TARGETARCH}" in amd64) echo x64;; arm64) echo arm64;; *) echo "${TARGETARCH}";; esac)" && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" | \
    tar -xJ -C /usr/local --strip-components=1 && \
    corepack enable && \
    corepack prepare yarn@1.22.22 --activate

COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/usr/local/bundle/cache,sharing=locked \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY package.json yarn.lock ./
RUN --mount=type=cache,target=/root/.cache/yarn,sharing=locked \
    yarn install --frozen-lockfile --prefer-offline

COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/

RUN yarn build:css

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

RUN rm -rf node_modules

FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
