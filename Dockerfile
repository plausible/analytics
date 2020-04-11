FROM elixir:alpine

ARG app_name=plausible
ARG phoenix_subdir=.
ARG build_env=prod
ARG AVIEN_DATABASE_URL=""

# Set up build environment.
ENV MIX_ENV=${build_env} \
  REPLACE_OS_VARS=true \
  TERM=xterm
ENV AVIEN_DATABASE_URL=${AVIEN_DATABASE_URL}
RUN set -xe
RUN echo "MIX_ENV=$MIX_ENV"
RUN echo "AVIEN_DATABASE_URL=$AVIEN_DATABASE_URL"

# Set the build directory.
RUN mkdir /opt/app
WORKDIR /opt/app

# Install build tools needed in addition to Elixir:
# NodeJS is used for Webpack builds of Phoenix assets.
# Hex and Rebar are needed to get and build dependencies.

# This step installs all the build tools we'll need
RUN apk update && \
  apk upgrade --no-cache && \
  apk add --no-cache \
  postgresql-client \
  nodejs \
  npm \
  git \
  build-base && \
  mix local.rebar --force && \
  mix local.hex --force

# Copy the application files into /opt/app.
COPY . .

# Build the application.
RUN mix do deps.get --only $MIX_ENV, deps.compile

# Build assets by running a Webpack build and Phoenix digest.
# If you are using a different mechanism for asset builds, you may need to
# alter these commands.
RUN cd ${phoenix_subdir}/assets \
  && npm install \
  && ./node_modules/webpack/bin/webpack.js --mode production \
  && cd .. \
  && mix phx.digest

# Create the release, and move the artifacts to well-known paths so the
# runtime image doesn't need to know the app name. Specifically, the binary
# is renamed to "start_server", and the entire release is moved into
# /opt/release.
RUN mix release \
  && mv _build/${build_env}/rel/${app_name} /opt/release \
  && mv /opt/release/bin/${app_name} /opt/release/bin/start_server

# # Step 2: Execute the application
# FROM alpine:latest

# RUN apk update \
#     && apk --no-cache --update add bash ca-certificates openssl-dev

ENV PORT=4000 \
  REPLACE_OS_VARS=true
EXPOSE ${PORT}
EXPOSE 8000

# # Set the install directory. The app will run from here.
# WORKDIR /opt/app

# # Obtain the built application release from the build stage.
# COPY --from=0 /opt/release .
# #COPY --from=releaser app/bin/ ./bin


# # Copy the Docker entrypoint.sh to the release docker image
# COPY --from=0 /opt/app/entrypoint.sh .

# # Start the server.

# # # CMD exec /opt/app/bin/start_server start

RUN chmod +x /opt/app/entrypoint.sh

# CMD /opt/app/entrypoint.sh
# CMD tail -f /dev/null

ENTRYPOINT /opt/app/entrypoint.sh
