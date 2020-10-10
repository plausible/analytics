# we can not use the pre-built tar because the distribution is
# platform specific, it makes sense to build it in the docker

#### Builder
FROM elixir:1.10.4-alpine as buildcontainer

# preparation
ARG APP_VER=0.0.1
ENV MIX_ENV=prod
ENV NODE_ENV=production
ENV APP_VERSION=$APP_VER

RUN mkdir /app
WORKDIR /app

# install build dependencies
RUN apk add --no-cache git nodejs yarn python npm ca-certificates wget gnupg make erlang gcc libc-dev && \
    npm install npm@latest -g && \
    npm install -g webpack

COPY mix.exs ./
COPY mix.lock ./
RUN mix local.hex --force && \
        mix local.rebar --force && \
        mix deps.get --only prod && \
        mix deps.compile

COPY assets/package.json assets/package-lock.json ./assets/
COPY tracker/package.json tracker/package-lock.json ./tracker/

RUN npm audit fix --prefix ./assets && \
    npm install --prefix ./assets && \
    npm install --prefix ./tracker

COPY assets ./assets
COPY tracker ./tracker
COPY config ./config
COPY priv ./priv
COPY lib ./lib

RUN npm run deploy --prefix ./assets && \
    npm run deploy --prefix ./tracker && \
    mix phx.digest priv/static

WORKDIR /app
COPY rel rel
RUN mix release plausible

# Main Docker Image
FROM alpine:3.11
LABEL maintainer="tckb <tckb@tgrthi.me>"
ENV LANG=C.UTF-8

RUN apk add --no-cache openssl ncurses

COPY .gitlab/build-scripts/docker-entrypoint.sh /entrypoint.sh

RUN chmod a+x /entrypoint.sh && \
    adduser -h /app -u 1000 -s /bin/sh -D plausibleuser

COPY --from=buildcontainer /app/_build/prod/rel/plausible /app
RUN chown -R plausibleuser:plausibleuser /app
USER plausibleuser
WORKDIR /app
ENTRYPOINT ["/entrypoint.sh"]
CMD ["run"]
