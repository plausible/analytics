---
title: Introduction
---

Plausible Analytics is designed to be self-hosted via Docker. You don't have to be a Docker expert
to launch your own instance of Plausible Analytics. You should have a basic understanding of the command-line
and networking to succesfully set up your own instance of Plausible Analytics.

NB: If you hit a snag with the setup, you can reach out to us on the forum. If you
think something could be better explained in the docs, please open a PR on Github
so the next person has a nicer experience. Happy hosting!

### Version management

Plausible follows [semantic versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

You can find available Plausible versions on [DockerHub](https://hub.docker.com/r/plausible/analytics). The default
`latest` tag refers to the latest stable release tag. You can also pin your version:

* `plausible/analytics:v1` pins the major version to `1` but allows minor and patch version upgrades
* `plausible/analytics:v1.2` pins the minor version to `1.2` but allows only patch upgrades

We consider the database schema an internal API. Therefore database schema changes require running migrations
but are not considered a breaking change.

None of the functionality is backported to older versions. If you wish to get the latest bug fixes and security
updates you need to upgrade to a newer version.

Version changes are documented in our [Changelog](https://github.com/plausible/analytics/blob/master/CHANGELOG.md).

### Requirements

The only thing you need to insall Plausible Analytics is a server with Docker installed. For the Plausible Cloud
instance we use [Digital Ocean](https://m.do.co/c/91569eca0213) (affiliate link) but any hosting provider works. If
your server doesn't come with Docker pre-installed, you can follow [their docs](https://docs.docker.com/get-docker/) to install it.

The Plausible server does not perform SSL termination (yet, feel free to contribute). It only runs on unencrypted HTTP.
If you want to run on HTTPS you also need to set up a reverse proxy in front of the server. For Plausible Cloud
we use Cloudflare to provide SSL termination and certificate mangement.

### Up and running

To get started, you need a `docker-compose.yml` file that configures the Plausible server along with its dependencies. Here
is a template to get you started. We have an example repository where you can find a basic docker-compose setup. To get started,
download both the `docker-compose.yml` and `plausible-conf.env` files onto your server (they must be in the same folder).

The `docker-compose.yml` file installs and orchestrates networking between your Plausible server, Postgres database, Clickhouse database (for stats), and an SMTP server. It comes with sensible defaults that are ready to go, although you're free to tweak the settings if you wish.

The `plausibble-conf.env` file configures the Plausible server itself. Refer to the [configuration](asd) section of this documentation
to see what's possible. To get started you only need to provide the `SECRET_KEY_BASE`. Any random string works as long as it's at least 32 characters long. The following command works on most machines: `openssl rand -base64 32`.

Once you've entered your secret key base, you're ready to start up the server:

```sh
$ docker-compose up
```

When you run this command for the first time, it will do the following:
* Creates a Postgres database for user data
* Creates a Clickhouse database for stats
* Runs migrations on both databases to prepare the schema
* Creates an admin account (which is just a normal account with a generous 100 years of free trial)
* Starts the server on port 8000

You can now navigate to `http://{hostname}:8000` and see the login screen.

> Something not working? Please reach out on our forum for troubleshooting.
