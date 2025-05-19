defmodule Plausible.Session.Salts do
  use GenServer
  use Plausible.Repo
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @impl true
  def init(opts) do
    name = opts[:name] || __MODULE__
    now = opts[:now] || DateTime.utc_now()
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
          Logger.notice("[salts] current current salt hash: #{:erlang.phash2(current)}")
          %{previous: prev, current: current}

        [current] ->
          Logger.notice("[salts] current current salt hash: #{:erlang.phash2(current)}")
          %{previous: nil, current: current}

        [] ->
          new = generate_and_persist_new_salt(now)
          %{previous: nil, current: new}
      end

    true = :ets.insert(name, {:state, state})
    {:ok, name}
  end

  def rotate(name \\ __MODULE__, now \\ DateTime.utc_now()) do
    GenServer.call(name, {:rotate, now})
  end

  @impl true
  def handle_call({:rotate, now}, _from, name) do
    current = fetch(name).current
    clean_old_salts(now)

    state =
      %{
        current: generate_and_persist_new_salt(now),
        previous: current
      }

    true = :ets.insert(name, {:state, state})
    {:reply, :ok, name}
  end

  def fetch(name \\ __MODULE__) do
    [state: state] = :ets.lookup(name, :state)

    state
  end

  defp generate_and_persist_new_salt(now) do
    salt = :crypto.strong_rand_bytes(16)
    Logger.notice("[salts] generated salt hash: #{:erlang.phash2(salt)}")
    Repo.insert_all("salts", [%{salt: salt, inserted_at: now}])
    salt
  end

  defp clean_old_salts(now) do
    h48_ago =
      DateTime.shift(now, hour: -48)

    Repo.delete_all(from s in "salts", where: s.inserted_at < ^h48_ago)
  end
end
