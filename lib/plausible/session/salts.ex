defmodule Plausible.Session.Salts do
  use Agent
  use Plausible.Repo

  def start_link(_opts) do
    Agent.start_link(
      fn ->
        clean_old_salts()

        salts =
          Repo.all(from s in "salts", select: s.salt, order_by: [desc: s.inserted_at], limit: 2)

        case salts do
          [current, prev] ->
            %{previous: prev, current: current}

          [current] ->
            %{previous: nil, current: current}

          [] ->
            new = generate_and_persist_new_salt()
            %{previous: nil, current: new}
        end
      end,
      name: __MODULE__
    )
  end

  def fetch() do
    Agent.get(__MODULE__, & &1)
  end

  def rotate() do
    Agent.update(__MODULE__, fn %{current: current} ->
      clean_old_salts()

      %{
        current: generate_and_persist_new_salt(),
        previous: current
      }
    end)
  end

  defp generate_and_persist_new_salt() do
    salt = :crypto.strong_rand_bytes(16)

    Repo.insert_all("salts", [%{salt: salt, inserted_at: Timex.now()}])
    salt
  end

  defp clean_old_salts() do
    Repo.delete_all(
      from s in "salts", where: s.inserted_at < fragment("now() - '48 hours'::interval")
    )
  end
end
