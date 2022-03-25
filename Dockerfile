# we can not use the pre-built tar because the distribution is
# platform specific, it makes sense to build it in the docker

#### Builder
FROM hexpm/elixir:1.12.2-erlang-24.0-alpine-3.13.3 as buildcontainer

# preparation
ARG APP_VER=0.0.1
ENV MIX_ENV=prod
ENV NODE_ENV=production
ENV APP_VERSION=$APP_VER

RUN mkdir /app
WORKDIR /app

# install build dependencies
RUN apk add --no-cache git nodejs yarn python3 npm ca-certificates wget gnupg make erlang gcc libc-dev && \
    npm install npm@latest -g && \
    npm install -g webpack

RUN wget https://s3.eu-central-1.wasabisys.com/plausible-application/geonames.csv -q

COPY mix.exs ./
COPY mix.lock ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    mix deps.compile

COPY assets/package.json assets/package-lock.json ./assets/
COPY tracker/package.json tracker/package-lock.json ./tracker/

RUN npm install --prefix ./assets && \
    npm install --prefix ./tracker

COPY assets ./assets
COPY tracker ./tracker
COPY config ./config
COPY priv ./priv
COPY lib ./lib

RUN npm run deploy --prefix ./assets && \
    npm run deploy --prefix ./tracker && \
    mix phx.digest priv/static && \
    mix download_country_database && \
# https://hexdocs.pm/sentry/Sentry.Sources.html#module-source-code-storage
    mix sentry_recompile && \
    mv geonames.csv ./priv/geonames.csv

WORKDIR /app
COPY rel rel
RUN mix release plausible

# Main Docker Image
FROM alpine:3.13.3
LABEL maintainer="tckb <tckb@tgrthi.me>"
ENV LANG=C.UTF-8

RUN apk upgrade --no-cache

RUN apk add --no-cache openssl ncurses libstdc++ libgcc

COPY .gitlab/build-scripts/docker-entrypoint.sh /entrypoint.sh

RUN chmod a+x /entrypoint.sh && \
    adduser -h /app -u 1000 -s /bin/sh -D plausibleuser

COPY --from=buildcontainer /app/_build/prod/rel/plausible /app
RUN chown -R plausibleuser:plausibleuser /app
USER plausibleuser
WORKDIR /app
ENV GEONAMES_SOURCE_FILE=/app/lib/plausible-0.0.1/priv/geonames.csv
ENV LISTEN_IP=0.0.0.0
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 8000
CMD ["run"]
