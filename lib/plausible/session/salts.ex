defmodule Plausible.Session.Salts do
  use GenServer
  use Plausible.Repo

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

    refresh(name, now)

    {:ok, name}
  end

  def refresh(name, now) do
    salts = Repo.all(from s in "salts", select: s.salt, order_by: [desc: s.id], limit: 2)

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
    Process.send_after(self(), {:refresh, now}, :timer.seconds(90))
    :ok
  end

  def rotate(name \\ __MODULE__, now \\ DateTime.utc_now()) do
    GenServer.call(name, {:rotate, now})
  end

  def fetch(name \\ __MODULE__) do
    [state: state] = :ets.lookup(name, :state)
    state
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

  @impl true
  def handle_info({:refresh, now}, name) do
    refresh(name, now)
    {:noreply, name}
  end

  defp generate_and_persist_new_salt(now) do
    salt = :crypto.strong_rand_bytes(16)
    Repo.insert_all("salts", [%{salt: salt, inserted_at: now}])
    salt
  end

  defp clean_old_salts(now) do
    h48_ago =
      DateTime.shift(now, hour: -48)

    Repo.delete_all(from s in "salts", where: s.inserted_at < ^h48_ago)
  end
end
