# Contributing

We welcome everyone to contribute to Plausible. This document is to help you on setting up your environment, finding a task, and opening pull requests.

## Development setup

The easiest way to get up and running is to [install](https://docs.docker.com/get-docker/) and use Docker for running both Postgres and Clickhouse.

Make sure Docker, Elixir, Erlang and Node.js are all installed on your development machine. The [`.tool-versions`](https://github.com/plausible/analytics/blob/master/.tool-versions) file is available to use with [asdf](https://github.com/asdf-vm/asdf) or similar tools.

### Start the environment

1. Run both `make postgres` and `make clickhouse`.
2. You can set up everything with `make install`, alternatively run each command separately:
    1. Run `mix deps.get`. This will download the required Elixir dependencies.
    2. Run `mix ecto.create`. This will create the required databases in both Postgres and Clickhouse.
    3. Run `mix ecto.migrate` to build the database schema.
    4. Run `mix run priv/repo/seeds.exs` to seed the database. Check the [Seeds](#Seeds) section for more.
    5. Run `npm ci --prefix assets` to install the required client-side dependencies.
    6. Run `npm ci --prefix tracker` to install the required tracker dependencies.
    7. Run `mix assets.setup` to install Tailwind and Esbuild
    8. Run `npm run deploy --prefix tracker` to generate tracker files in `priv/tracker/js`
    9. Run `mix download_country_database` to fetch geolocation database
3. Run `make server` or `mix phx.server` to start the Phoenix server.
4. The system is now available on `localhost:8000`.

### Seeds

You can optionally seed your database to automatically create an account and a site with stats:

1. Run `mix run priv/repo/seeds.exs` to seed the database.
2. Start the server with `make server` and navigate to `http://localhost:8000/login`.
3. Log in with the following e-mail and password combination: `user@plausible.test` and `plausible`.
4. You should now have a `dummy.site` site with generated stats.

Alternatively, you can manually create a new account:

1. Navigate to `http://localhost:8000/register` and fill in the form.
2. Fill in the rest of the forms and for the domain use `dummy.site`
3. Skip the JS snippet and click start collecting data.
4. Run `mix send_pageview` from the terminal to generate a fake pageview event for the dummy site.
5. You should now be all set!

### Stopping Docker containers

1. Stop and remove the Postgres container with `make postgres-stop`.
2. Stop and remove the Clickhouse container with `make clickhouse-stop`.

Volumes are preserved. You'll find that the Postgres and Clickhouse state are retained when you bring them up again the next time: no need to re-register and so on.

Note: Since we are deleting the containers, be careful when deleting volumes with `docker volume prune`. You might accidentally delete the database and would have to go through re-registration process.

### Pre-commit hooks

`pre-commit` requires Python to be available locally and covers Elixir, JavaScript, and CSS. Set up with `pip install --user pre-commit` followed by `pre-commit install`. Conversely, if the prompts are far too bothersome, remove with `pre-commit uninstall`.

## Finding a task

Bugs can be found in our [issue tracker](https://github.com/plausible/analytics/issues). Issues are usually up for grabs.

New features need to be discussed with the core team and the community first. If you're tackling a feature, please make sure it has been already discussed in the [Discussions tab](https://github.com/plausible/analytics/discussions). We kindly ask contributors to use the discussion comment section to propose a solution before opening a pull request.

Pull requests without an associated issue or discussion may still be merged, but we will focus on changes that have already been talked through.
