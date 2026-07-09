defmodule Plausible.Session.ComputedSalts do
  @moduledoc """
  Cache for computed salts used for replayed events.

  It's not cleaned, however the range of possible values is limited
  to the number of replayed sessions over the lifetime of the node
  and sessions IDs can't be provided externally by users.

  Despite that, the cache is still purged every couple hours.
  """

  @purge_interval :timer.seconds(7200)

  use GenServer

  alias Plug.Crypto.KeyGenerator

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @impl true
  def init(opts) do
    name = opts[:name] || __MODULE__

    ^name =
      :ets.new(name, [
        :named_table,
        :set,
        :public,
        {:read_concurrency, true}
      ])

    schedule_purge()

    {:ok, name}
  end

  @spec fetch(module() | atom(), pos_integer()) :: %{previous: nil, current: binary()}
  def fetch(name \\ __MODULE__, replay_session_id) do
    computed_salt =
      secret_key_base()
      |> KeyGenerator.generate(:binary.encode_unsigned(replay_session_id), cache: name)
      |> binary_part(0, 16)

    %{previous: nil, current: computed_salt}
  end

  @impl true
  def handle_info(:purge, name) do
    :ets.delete_all_objects(name)
    schedule_purge()

    {:noreply, name}
  end

  defp schedule_purge() do
    Process.send_after(self(), :purge, @purge_interval)
  end

  defp secret_key_base() do
    Application.get_env(:plausible, PlausibleWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
