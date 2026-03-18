defmodule Plausible.Ingestion.Analyzer do
  @moduledoc """
  Service and API for recording ingest requests of particular domains.
  """

  use GenServer

  import Ecto.Query, only: [from: 2]

  alias Plausible.RateLimit
  alias Plausible.Repo
  alias __MODULE__

  @max_rate 10
  @rate_limit_key "ingestion_analyzer"
  @refresh_interval :timer.seconds(1)
  @flush_interval :timer.seconds(5)
  @flush_threshold 2000
  @log_retention_hours 24

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    Analyzer.Sites =
      :ets.new(Analyzer.Sites, [
        :named_table,
        :set,
        :protected,
        {:read_concurrency, true}
      ])

    schedule_sites_refresh()
    flush_timer = schedule_flush()

    {:ok, %{active_sites?: false, buffer: [], flush_timer: flush_timer}}
  end

  def maybe_record(request, headers, drop_reason, now \\ NaiveDateTime.utc_now()) do
    if get_active(request.domains) != [] and check_rate_limit() == :ok do
      GenServer.cast(__MODULE__, {:record, request, headers, drop_reason, now})
    else
      :ok
    end
  end

  def start_recording(domain, limit, now \\ NaiveDateTime.utc_now(:second)) do
    domain
    |> Analyzer.Site.create_changeset(limit, now)
    |> Repo.insert(
      on_conflict: [set: [updated_at: now, limit: limit]],
      conflict_target: :domain,
      returning: true
    )
  end

  def stop_recording(domain) do
    Repo.delete_all(from as in Analyzer.Site, where: as.domain == ^domain)
    :ok
  end

  def purge_log(domain) do
    Repo.delete_all(from l in Analyzer.Log, where: l.domain == ^domain)
    :ok
  end

  def remove_old_logs(now \\ NaiveDateTime.utc_now()) do
    cutoff_time = NaiveDateTime.shift(now, hour: -1 * @log_retention_hours)

    Repo.delete_all(from l in Analyzer.Log, where: l.inserted_at < ^cutoff_time)
    :ok
  end

  @impl true
  def handle_cast({:record, request, headers, drop_reason, now}, state) do
    if active_sites = state.active_sites? && get_active(request.domains) do
      request_payload =
        request
        |> Map.from_struct()
        |> Map.delete(:__meta__)
        |> Map.delete(:domains)

      headers_payload = Enum.group_by(headers, &elem(&1, 0), &elem(&1, 1))

      entries =
        Enum.map(active_sites, fn {domain, limit, updated_at} ->
          :ets.insert(Analyzer.Sites, {domain, limit - 1, updated_at})

          %{
            domain: domain,
            request: request_payload,
            headers: headers_payload,
            drop_reason: if(drop_reason, do: inspect(drop_reason)),
            inserted_at: now
          }
        end)

      new_buffer = entries ++ state.buffer

      if length(new_buffer) >= @flush_threshold do
        Process.cancel_timer(state.flush_timer)
        flush(new_buffer)
        schedule_flush()
        {:noreply, %{state | buffer: []}}
      else
        {:noreply, %{state | buffer: new_buffer}}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:refresh_sites, state) do
    now = NaiveDateTime.utc_now(:second)
    active_sites? = refresh_sites(now)
    schedule_sites_refresh()

    {:noreply, %{state | active_sites?: active_sites?}}
  end

  def handle_info(:flush, state) do
    Process.cancel_timer(state.flush_timer)
    flush(state.buffer)
    schedule_flush()

    {:noreply, %{state | buffer: []}}
  end

  defp get_active(domains) do
    Enum.reduce(domains, [], fn domain, active ->
      case lookup_site(domain) do
        {:ok, entry} -> [entry | active]
        _ -> active
      end
    end)
  end

  defp check_rate_limit() do
    case RateLimit.check_rate(@rate_limit_key, to_timeout(second: 1), @max_rate) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limit}
    end
  end

  defp lookup_site(domain) do
    if :ets.whereis(Analyzer.Sites) != :undefined do
      case :ets.lookup(Analyzer.Sites, domain) do
        [{_, limit, _} = site] when limit > 0 ->
          {:ok, site}

        _ ->
          {:error, :not_found}
      end
    else
      {:error, :not_running}
    end
  end

  defp schedule_sites_refresh() do
    Process.send_after(self(), :refresh_sites, @refresh_interval)
  end

  defp schedule_flush() do
    Process.send_after(self(), :flush, @flush_interval)
  end

  defp flush(buffer) do
    Repo.insert_all(Analyzer.Log, buffer)
  end

  defp refresh_sites(now) do
    cached_sites =
      Analyzer.Sites
      |> :ets.tab2list()
      |> Map.new(fn {domain, limit, updated_at} ->
        {domain, %{domain: domain, limit: limit, updated_at: updated_at}}
      end)

    site_domains =
      from(as in Analyzer.Site,
        where: as.valid_until > ^now,
        select: %{domain: as.domain, limit: as.limit, updated_at: as.updated_at}
      )
      |> Repo.all()
      |> Enum.map(fn site ->
        cached = cached_sites[site.domain]

        if is_nil(cached) or NaiveDateTime.compare(site.updated_at, cached.updated_at) == :gt do
          site
        else
          cached
        end
      end)
      |> Enum.map(fn site ->
        :ets.insert(Analyzer.Sites, {site.domain, site.limit, site.updated_at})
        site.domain
      end)
      |> MapSet.new()

    Enum.each(cached_sites, fn {domain, _} ->
      if not MapSet.member?(site_domains, domain) do
        :ets.delete(Analyzer.Sites, domain)
      end
    end)

    MapSet.size(site_domains) > 0
  end
end
