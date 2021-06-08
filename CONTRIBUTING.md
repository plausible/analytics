# Contributing

## Development setup

The easiest way to get up and running is to [install](https://docs.docker.com/get-docker/) and use Docker for running both Postgres and Clickhouse.

Make sure Docker, Elixir, Erlang and Node.js are all installed on your development machine.

### Start the environment:

1. Run both `make postgres` and `make clickhouse`.
2. You can then get set up with the following bits in one go with `make install`.
  1. Run `mix deps.get`. This will download the required Elixir dependencies.
  2. Run `mix ecto.create`. This will create the required databases in both Postgres and Clickhouse.
  3. Run `mix ecto.migrate` to build the database schema.
  4. Run `npm ci --prefix assets` to install the required node dependencies.
3. Run `make server` or `mix phx.server` to start the Phoenix server.
4. The system is now available on `localhost:8000`.

### Creating an account

1. Navigate to `http://localhost:8000/register` and fill in the form.
2. An e-mail won't actually be sent, but you can find the activation in the Phoenix logs in your terminal. Search for `%Bamboo.Email{assigns: %{link: "` and open the link listed.
3. Fill in the rest of the forms and for the domain use `dummy.site`
4. Run `make dummy_event` from the terminal to generate a fake pageview event for the dummy site.
5. You should now be all set!

### Stopping Docker containers

1. Stop and remove the Postgres container with `make postgres-stop`.
2. Stop and remove the Clickhouse container with `make clickhouse-stop`.

Volumes are preserved. You'll find that the Postgres and Clickhouse state are retained when you bring them up again the next time: no need to re-register and so on.

Note: Since we are deleting the containers, be careful when deleting volumes with `docker volume prune`. You might accidentally delete the database and would have to go through re-registration process.

### Pre-commit hooks

`pre-commit` requires Python to be available locally and covers JavaScript and CSS. Set up with `pip install --user pre-commit` followed by `pre-commit install`. Conversely, if the prompts are far too bothersome, remove with `pre-commit uninstall`.