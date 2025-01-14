# we can not use the pre-built tar because the distribution is
# platform specific, it makes sense to build it in the docker

#### Builder
FROM hexpm/elixir:1.17.1-erlang-27.0-alpine-3.20.1 AS buildcontainer

ARG MIX_ENV=ce

# preparation
ENV MIX_ENV=$MIX_ENV
ENV NODE_ENV=production
ENV NODE_OPTIONS=--openssl-legacy-provider

# custom ERL_FLAGS are passed for (public) multi-platform builds
# to fix qemu segfault, more info: https://github.com/erlang/otp/pull/6340
ARG ERL_FLAGS
ENV ERL_FLAGS=$ERL_FLAGS

RUN mkdir /app
WORKDIR /app

# install build dependencies
RUN apk add --no-cache git "nodejs-current=21.7.3-r0" yarn npm python3 ca-certificates wget gnupg make gcc libc-dev brotli

COPY mix.exs ./
COPY mix.lock ./
COPY config ./config
RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get --only ${MIX_ENV} && \
  mix deps.compile

COPY assets/package.json assets/package-lock.json ./assets/
COPY tracker/package.json tracker/package-lock.json ./tracker/

RUN npm install --prefix ./assets && \
  npm install --prefix ./tracker

COPY assets ./assets
COPY tracker ./tracker
COPY priv ./priv
COPY lib ./lib
COPY extra ./extra
COPY storybook ./storybook

RUN npm run deploy --prefix ./tracker && \
  mix assets.deploy && \
  mix phx.digest priv/static && \
  mix download_country_database && \
  mix sentry.package_source_code

WORKDIR /app
COPY rel rel
RUN mix release plausible

# Main Docker Image
FROM alpine:3.20.1
LABEL maintainer="plausible.io <hello@plausible.io>"

ARG BUILD_METADATA={}
ENV BUILD_METADATA=$BUILD_METADATA
ENV LANG=C.UTF-8
ARG MIX_ENV=ce
ENV MIX_ENV=$MIX_ENV

RUN adduser -S -H -u 999 -G nogroup plausible

RUN apk upgrade --no-cache
RUN apk add --no-cache openssl ncurses libstdc++ libgcc ca-certificates \
  && if [ "$MIX_ENV" = "ce" ]; then apk add --no-cache certbot; fi

COPY --from=buildcontainer --chmod=555 /app/_build/${MIX_ENV}/rel/plausible /app
COPY --chmod=755 ./rel/docker-entrypoint.sh /entrypoint.sh

# we need to allow "others" access to app folder, because
# docker container can be started with arbitrary uid
RUN mkdir -p /var/lib/plausible && chmod ugo+rw -R /var/lib/plausible

USER 999
WORKDIR /app
ENV LISTEN_IP=0.0.0.0
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 8000
ENV DEFAULT_DATA_DIR=/var/lib/plausible
VOLUME /var/lib/plausible
CMD ["run"]
