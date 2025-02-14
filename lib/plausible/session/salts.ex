defmodule Plausible.Session.Salts do
  use Agent
  use Plausible.Repo

  def start_link(opts) do
    name = opts[:name] || __MODULE__

    Agent.start_link(
      fn ->
        now = opts[:now] || DateTime.utc_now()
        IO.inspect(:clean, label: name)
        clean_old_salts(now)

        ^name =
          :ets.new(name, [
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
              new = generate_and_persist_new_salt(now)
              %{previous: nil, current: new}
          end

        true = :ets.insert(name, {:state, state})
        {:ok, name}
      end,
      name: name
    )
  end

  def fetch(name \\ __MODULE__) do
    [state: state] = :ets.lookup(name, :state)

    state
    |> IO.inspect(label: :fetch)
  end

  def rotate(name \\ __MODULE__, now \\ DateTime.utc_now()) do
    Agent.update(name, fn {:ok, ^name} ->
      IO.inspect(now, label: :rotate)
      current = fetch(name).current
      IO.inspect :clean, label: name
      clean_old_salts(now)

      state =
        %{
          current: generate_and_persist_new_salt(now),
          previous: current
        }
        |> IO.inspect(label: :insert)

      true = :ets.insert(name, {:state, state})
      {:ok, name}
    end)
  end

  defp generate_and_persist_new_salt(now) do
    salt = :crypto.strong_rand_bytes(16)

    Repo.insert_all("salts", [%{salt: salt, inserted_at: now}])
    IO.inspect(salt, label: now)
    salt
  end

  defp clean_old_salts(now) do
    h48_ago =
      DateTime.shift(now, hour: -48)
      |> IO.inspect(label: :clean_old_salts)

    Repo.delete_all(from s in "salts", where: s.inserted_at < ^h48_ago)
    |> IO.inspect(label: :number_cleaned)
  end
end
