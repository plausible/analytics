# Contributing

## Development setup

The easiest way to get up and running is to [install](https://docs.docker.com/get-docker/) and use Docker for running both Postgres and Clickhouse.

### Start the environment:

1. Run both `make postgres` and `make clickhouse`.
2. Run `mix ecto.create`. This will create the required databases in both Postgres and Clickhouse.
3. Run `mix ecto.migrate` to build the database schema.
4. Run `npm ci --prefix assets` to install the required node dependencies.
5. Run `mix phx.server` to start the Phoenix server.
6. The system is now available on `localhost:8000`.

### Creating an account

1. Navigate to `http://localhost:8000/register` and fill in the form.
2. An e-mail won't actually be sent, but you can find the activation in the Phoenix logs in your terminal. Search for `%Bamboo.Email{assigns: %{link: "` and open the link listed.
3. Fill in the rest of the forms and for the domain use `dummy.site`
4. Run `make dummy_event` from the terminal to generate a fake pageview event for the dummy site.
5. You should now be all set!
