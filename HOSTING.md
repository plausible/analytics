---
status: Beta
---

# Plausible Analytics

Self-hosting is possible based on the docker images and are automatically pushed into [Dockerhub](https://hub.docker.com/r/plausible/analytics) registry for all commits on `master` branch. At the moment, `latest` is the only tag on DockerHub as we haven't reached a stable release of self-hosted Plausible yet.

### Architecture

Plausible runs as a single server, backed by two databases: PostgreSQL for user data and ClickhouseDB for the stats. When you
download and run the docker image you also need to provide connection details for these two databases.

Most hosting providers will offer a managed PostgreSQL instance, but it's not as simple with Clickhouse.
You can [install Clickhouse on a VPS](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-clickhouse-on-ubuntu-18-04),
run it using their [official Docker image](https://hub.docker.com/r/yandex/clickhouse-server/), or use a managed service provided by
[Yandex Cloud](https://cloud.yandex.com/services/managed-clickhousec). [Aiven has announced](https://landing.aiven.io/2020-upcoming-aiven-services-webinar) that they are planning offer a managed ClickHouse service in the future and more hosting providers are following suit.

As of June 2020, here's the setup of the official cloud version of Plausible for reference:
* Web server: Digital Ocean Droplet w/ 1vCPU & 2GB RAM. Managed via the [official Docker app](https://marketplace.digitalocean.com/apps/docke://marketplace.digitalocean.com/apps/docker).
* User database: Digital Ocean Managed PostgreSQL w/ 1vCPU & 1GB RAM.
* Stats database: Digital Ocean Droplet w/ 6vCPU & 16GB RAM. Installed on Ubuntu 18.04 using the [official tutorial](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-clickhouse-on-ubuntu-18-04)

Total cost: $105/mo

### Building Docker image
Besides the DockerHub registry, one can build docker image from [Dockerfile](./Dockerfile).

#### Up and Running
The repo supplies with a [Docker Compose](./docker-compose.yml) file and the sample [environment variables](./plausible-variables.sample.env) , this serves as a sample for running Plausible with Docker.

-  Running the setup takes care of the initial migration steps, this needs to be executed only once, on the first run.
    ```bash
    docker-compose run --rm setup
    docker-compose down
    ```

- After the setup, you can start plausible as --
    ```bash
    docker-compose up -d plausible
    ```
     after a successful startup (can take upto 5 mins), `plausible` is available at port `80`, navigate to [`http://localhost`](http://localhost).

- stopping plausible --
    ```bash
    docker-compose down
    ```
- purging and removing everything --
    ```bash
    docker-compose down
    docker volume rm plausible_event-data -f
    docker volume rm plausible_db-data -f
    ```
Note:
- #1 you need to stop plausible and restart plausible  if you change the environment variables.
- #2 With docker-compose, you need to remove the existing container and rebuild if you want your changes need to be reflected:
    ```bash
    docker rmi -f  plausible_plausible:latest
    docker-compose up -d plausible
    ```
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
_build/prod/rel/plausible/init-admin.sh
_build/prod/rel/plausible/migrate.sh
_build/prod/rel/plausible/rollback.sh
_build/prod/rel/plausible/seed.sh
```

the same is available in the docker images as follows --

```bash
docker run plausible:master-12add db createdb
docker run plausible:master-12add db init-admin
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
- SCHEME (*String*)
    - The scheme of the URL, either `http` or `https`. When using a reverse proxy with https, it'll be required to set this. _defaults to `http`_
- PORT (*Number*)
    - The port on which the server is available.
- SECRET_KEY_BASE (*String*)
    - An internal secret key used by [Phoenix Framework](https://www.phoenixframework.org/). Follow the [instructions](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Secret.html#content) to generate one.
- ENVIRONMENT (*String*)
    - The current running environment. _defaults to **prod**_
- APP_VERSION (*String*)
    - The version of the app running. _defaults to current docker tag_
- DISABLE_AUTH  (*Boolean String*)
    - Disables authentication completely, no registration, login will be shown. _defaults to `false`_
    - Note: This option is **not recommended** for production deployments.
- DISABLE_REGISTRATION
  - Disables registration of new users, keep your admin credentials handy ;)  _defaults to `false`_
- DISABLE_SUBSCRIPTION
  - Disables changing of subscription and removes the trial notice banner (use with caution!) _defaults to `false`_

### Default User Generation
For self-hosting, a default user can be generated using the `db init-admin` command. To be noted that, a default user is a user whose trial period expires in 100 Years ;).
It is *highly* recommended that you configure these parameters.

- ADMIN_USER_NAME
    - The default ("admin") username. _if not provided, one will be generated for you_
- ADMIN_USER_EMAIL
    - The default ("admin") user email. _if not provided, one will be generated for you_
- ADMIN_USER_PWD
    - The default ("admin") user password. _if not provided, one will be generated for you_

### Mailer/SMTP Setup

- MAILER_ADAPTER (*String*)
    - The adapter used for sending out e-mails. Available: `Bamboo.PostmarkAdapter` / `Bamboo.SMTPAdapter`
- MAILER_EMAIL (*String*)
    - The email id to use for as _from_ address of all communications from Plausible.

In case of `Bamboo.SMTPAdapter` you need to supply the following variables:

- SMTP_HOST_ADDR (*String*)
    - The host address of your smtp server.
- SMTP_HOST_PORT (*Number*)
    - The port of your smtp server.
- SMTP_USER_NAME (*String*)
    - The username/email for smtp auth.
- SMTP_USER_PWD (*String*)
    - The password for smtp auth.
- SMTP_HOST_SSL_ENABLED (*Boolean String*)
    - If ssl is enabled for connecting to Smtp, _defaults to `false`_
- SMTP_RETRIES (*Number*)
    - Number of retries to make until mailer gives up. _defaults to `2`_
- SMTP_MX_LOOKUPS_ENABLED (*Boolean String*)
    - If MX lookups should be done before sending out emails. _defaults to `false`_

### Database

Plausible uses [postgresql as database](https://www.tutorialspoint.com/postgresql/postgresql_environment.htm) for storing all the user-data. Use the following the variables to configure it.

- DATABASE_URL (*String*)
    - The repo Url as dictated [here](https://hexdocs.pm/ecto/Ecto.Repo.html#module-urls)
- DATABASE_POOL_SIZE (*Number*)
    -  A default pool size for connecting to the database, defaults to *10*, a higher number is recommended for a production system.
- DATABASE_TLS_ENABLED (*Boolean String*)
    - A flag that says whether to connect to the database via TLS, read [here](https://www.postgresql.org/docs/10/ssl-tcp.html)

For performance reasons, all the analytics events are stored in [clickhouse](https://clickhouse.tech/docs/en/getting-started/tutorial/):

- CLICKHOUSE_DATABASE_HOST (*String*)
- CLICKHOUSE_DATABASE_NAME (*String*)
- CLICKHOUSE_DATABASE_USER (*String*)
- CLICKHOUSE_DATABASE_PASSWORD (*String*)
- CLICKHOUSE_DATABASE_POOLSIZE (*Number*)
    - A default pool size for connecting to the database, defaults to *10*, a higher number is recommended for a production system.

### IP Geolocation

Plausible uses the GeoLite2 database created by [MaxMind](https://www.maxmind.com) for enriching analytics data with visitor countries. Their
end-user license does not make it very easy to just package the database along with an open-source product. This is why, if you want
to get country data for your analytics, you need to create an account and download their **GeoLite2 Country** database.

Once you have the database, mount it on the Plausible docker image and configure the path of the database file:
- GEOLITE2_COUNTRY_DB (*String*)

If the Geolite database is not configured, no country data will be captured.

### External Services

- [Google Client](https://developers.google.com/api-client-library)
    - GOOGLE_CLIENT_ID
    - GOOGLE_CLIENT_SECRET
- [Sentry](https://sentry.io/)
    - SENTRY_DSN
- [Paddle](https://paddle.com/)
    - PADDLE_VENDOR_AUTH_CODE
- [PostMark](https://postmarkapp.com/), only in case of `Bamboo.PostmarkAdapter` mail adapter.
    - POSTMARK_API_KEY

Apart from these, there are also the following integrations

- [Twitter](https://developer.twitter.com/en/docs)
    - TWITTER_CONSUMER_KEY
    - TWITTER_CONSUMER_SECRET
    - TWITTER_ACCESS_TOKEN
    - TWITTER_ACCESS_TOKEN_SECRET
- [Slack](https://api.slack.com/messaging/webhooks)
    - SLACK_WEBHOOK
