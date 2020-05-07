# Plausible Insights
Self-hosting is possible based on the docker images and are automatically pushed into [Gitlab hosted docker](registry.gitlab.com/tckb-public/plausible) registry for all commits on `master` branch.    
All `master-*` tags are considered to be stable and are persisted. Any other tag in the registry is considered to be for development purposes and/or unstable and are auto-deleted after a week.


### Building Docker image
Besides the GitlabCI, one can build docker image from [Dockerfile](./Dockerfile). 

### Non-docker building
It is possible to create a release artifact by running a release. 

```elixir
MIX_ENV=prod mix release plausible
```
the release will create the pre-packed artifact at `_build/prod/rel/plausible/bin/plausible`, the release will also create a tarball at `_build/prod/` for convenience. 

Note, that you have to feed in the related environment variables (see below `Environment Variables`)

## Database Migration
On the initial setup, a migration step is necessary to create database and table schemas needed for initial bootup. 
Normally, this done by mix aliases like `ecto.setup` defined in the `mix.exs`. As this not available in "released" artifact,  [`plausible_migration.ex`](./lib/plausible_migration.ex) facilitates this process. 
The overlay [scripts](./rel/overlays) take care of these.

After the release, these are available under  `_build/prod/rel/plausible` --


```bash
_build/prod/rel/plausible/createdb.sh
_build/prod/rel/plausible/migrate.sh
_build/prod/rel/plausible/rollback.sh
_build/prod/rel/plausible/seed.sh
```

the same is available in the docker images as follows --

```bash
docker run plausible:master-12add db createdb
docker run plausible:master-12add db migrate
docker run plausible:master-12add db rollback
docker run plausible:master-12add db seed
```


## Environment Variables
Plausible relies on the several services for operating, the expected environment variables are explaiend below.  

### Server
Following are the variables that can be used to configure the availability of the server.

- HOST (*String*)
    - The hosting address of the server. For running on local system, this can be set to **localhost**. In production systems, this can be your ingress host.
- PORT (*Number*)
    - The port on which the server is available. 
- SECRET_KEY_BASE (*String*)
    - An internal secret key used by [Phoenix Framework](https://www.phoenixframework.org/). Follow the [instructions](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Secret.html#content) to generate one. 

### Database
Plausible uses postgresql as database for storing all the data. Use the following the variables to configure it.

- DATABASE_URL (*String*)
    - The repo Url as dictated [here](https://hexdocs.pm/ecto/Ecto.Repo.html#module-urls)
- DATABASE_POOL_SIZE (*Number*)
    -  A default pool size for connecting to the database, defaults to *10*, a higher number is recommended for a production system.
- DATABASE_TLS_ENABLED (*Boolean String*)
    - A flag that says whether to connect to the database via TLS, read [here](https://www.postgresql.org/docs/10/ssl-tcp.html)

### External Services

- [Google Client](https://developers.google.com/api-client-library)
    - GOOGLE_CLIENT_ID
    - GOOGLE_CLIENT_SECRET
- [Sentry](https://sentry.io/) 
    - SENTRY_DSN
- [Paddle](https://paddle.com/)
    - PADDLE_VENDOR_AUTH_CODE
- [PostMark](https://postmarkapp.com/)
    - POSTMARK_API_KEY

Apart from these, there are also the following integrations 

- [Twitter](https://developer.twitter.com/en/docs)
    - TWITTER_CONSUMER_KEY
    - TWITTER_CONSUMER_SECRET
    - TWITTER_ACCESS_TOKEN
    - TWITTER_ACCESS_TOKEN_SECRET
- [Slack](https://api.slack.com/messaging/webhooks) 
    - SLACK_WEBHOOK
