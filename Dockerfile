# we can not use the pre-built tar because the distribution is
# platform specific, it makes sense to build it in the docker

#### Builder
FROM elixir:1.10.3 as buildcontainer

# preparation
ARG APP_VER=0.0.1
ENV GOSU_VERSION 1.11
ENV MIX_ENV=prod
ENV NODE_ENV=production
ENV APP_VERSION=$APP_VER

RUN mkdir /app
WORKDIR /app

# install build dependencies
RUN apt-get update  && \
    apt-get install -y git build-essential nodejs yarn python npm --no-install-recommends && \
    npm install npm@latest -g && \
    npm install -g webpack

RUN apt-get install -y --no-install-recommends ca-certificates wget \
    && apt-get install -y --install-recommends gnupg2 dirmngr

# grab gosu for easy step-down from root
RUN set -x \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && command -v gpgconf && gpgconf --kill all || : \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu --version \
    && gosu nobody true

COPY config ./config
COPY assets ./assets
COPY priv ./priv
COPY lib ./lib
COPY mix.exs ./
COPY mix.lock ./
RUN mix local.hex --force && \
        mix local.rebar --force && \
        mix deps.get --only prod && \
        mix deps.compile

RUN npm audit fix --prefix ./assets && \
    npm install --prefix ./assets && \
    npm run deploy --prefix ./assets && \
    mix phx.digest priv/static

WORKDIR /app
COPY rel rel
RUN mix release plausible


# Main Docker Image
FROM debian:bullseye
LABEL maintainer="tckb <tckb@tgrthi.me>"
ENV LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y bash openssl --no-install-recommends&& \
    apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/

COPY .gitlab/build-scripts/docker-entrypoint.sh /entrypoint.sh

RUN chmod a+x /entrypoint.sh && \
    useradd -d /app -u 1000 -s /bin/bash -m plausibleuser

COPY --from=buildcontainer /usr/local/bin/gosu /usr/local/bin/gosu
COPY --from=buildcontainer /app/_build/prod/rel/plausible /app
RUN chown -R plausibleuser:plausibleuser /app
WORKDIR /app
ENTRYPOINT ["/entrypoint.sh"]
CMD ["run"]
