defmodule Plausible.Session.Salts do
  use Agent
  use Plausible.Repo

  def start_link(_opts) do
    Agent.start_link(
      fn ->
        clean_old_salts()

        __MODULE__ =
          :ets.new(__MODULE__, [
            :named_table,
            :set,
            :protected,
            {:read_concurrency, true}
          ])

        salts =
          Repo.all(from s in "salts", select: s.salt, order_by: [desc: s.inserted_at], limit: 2)

        state =
          case salts do
            [current, prev] ->
              %{previous: prev, current: current}

            [current] ->
              %{previous: nil, current: current}

            [] ->
              new = generate_and_persist_new_salt()
              %{previous: nil, current: new}
          end

        true = :ets.insert(__MODULE__, {:state, state})
        :ok
      end,
      name: __MODULE__
    )
  end

  def fetch() do
    [state: state] = :ets.lookup(__MODULE__, :state)
    state
  end

  def rotate() do
    Agent.update(__MODULE__, fn :ok ->
      current = fetch().current
      clean_old_salts()

      state = %{
        current: generate_and_persist_new_salt(),
        previous: current
      }

      true = :ets.insert(__MODULE__, {:state, state})
      :ok
    end)
  end

  defp generate_and_persist_new_salt() do
    salt = :crypto.strong_rand_bytes(16)

    Repo.insert_all("salts", [%{salt: salt, inserted_at: DateTime.utc_now()}])
    salt
  end

  defp clean_old_salts() do
    Repo.delete_all(
      from s in "salts", where: s.inserted_at < fragment("now() - '48 hours'::interval")
    )
  end
end
