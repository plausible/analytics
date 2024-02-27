defmodule Plausible.TestUtils do
  use Plausible.Repo
  alias Plausible.Factory

  defmacro __using__(_) do
    quote do
      require Plausible.TestUtils
      import Plausible.TestUtils
    end
  end

  defmacro patch_env(env_key, value) do
    quote do
      if __MODULE__.__info__(:attributes)[:ex_unit_async] == [true] do
        raise "Patching env is unsafe in asynchronous tests. maybe extract the case elsewhere?"
      end

      original_env = Application.get_env(:plausible, unquote(env_key))
      Application.put_env(:plausible, unquote(env_key), unquote(value))

      on_exit(fn ->
        Application.put_env(:plausible, unquote(env_key), original_env)
      end)

      {:ok, %{patched_env: true}}
    end
  end

  defmacro setup_patch_env(env_key, value) do
    quote do
      setup do
        patch_env(unquote(env_key), unquote(value))
      end
    end
  end

  def create_user(_) do
    {:ok, user: Factory.insert(:user)}
  end

  def create_site(%{user: user}) do
    site =
      Factory.insert(:site,
        members: [user]
      )

    {:ok, site: site}
  end

  def add_imported_data(%{site: site}) do
    site =
      site
      |> Plausible.Site.start_import(~D[2005-01-01], Timex.today(), "Google Analytics", "ok")
      |> Repo.update!()

    {:ok, site: site}
  end

  def create_new_site(%{user: user}) do
    site = Factory.insert(:site, members: [user])
    {:ok, site: site}
  end

  def create_api_key(%{user: user}) do
    api_key = Factory.insert(:api_key, user: user)

    {:ok, api_key: api_key.key}
  end

  def use_api_key(%{conn: conn, api_key: api_key}) do
    conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key}")

    {:ok, conn: conn}
  end

  def create_pageviews(pageviews) do
    pageviews =
      Enum.map(pageviews, fn pageview ->
        pageview =
          pageview
          |> Map.delete(:site)
          |> Map.put(:site_id, pageview.site.id)

        Factory.build(:pageview, pageview)
        |> update_in([:timestamp], &to_naive_truncate/1)
        |> Map.delete(:_factory_event)
      end)

    Plausible.IngestRepo.insert_all(Plausible.ClickhouseEventV2, pageviews)
  end

  def create_events(events) do
    events =
      Enum.map(events, fn event ->
        Factory.build(:event, event)
        |> update_in([:timestamp], &to_naive_truncate/1)
        |> Map.delete(:_factory_event)
      end)

    Plausible.IngestRepo.insert_all(Plausible.ClickhouseEventV2, events)
  end

  def create_sessions(sessions) do
    sessions =
      Enum.map(sessions, fn session ->
        Factory.build(:ch_session, session)
        |> Map.from_struct()
        |> Map.delete(:__meta__)
        |> update_in([:timestamp], &to_naive_truncate/1)
        |> update_in([:start], &to_naive_truncate/1)
      end)

    Plausible.IngestRepo.insert_all(Plausible.ClickhouseSessionV2, sessions)
  end

  def log_in(%{user: user, conn: conn}) do
    conn =
      init_session(conn)
      |> Plug.Conn.put_session(:current_user_id, user.id)

    {:ok, conn: conn}
  end

  def init_session(conn) do
    opts =
      Plug.Session.init(
        store: :cookie,
        key: "foobar",
        encryption_salt: "encrypted cookie salt",
        signing_salt: "signing salt",
        log: false,
        encrypt: false
      )

    conn
    |> Plug.Session.call(opts)
    |> Plug.Conn.fetch_session()
  end

  def generate_usage_for(site, i, timestamp \\ NaiveDateTime.utc_now()) do
    events = for _i <- 1..i, do: Factory.build(:pageview, timestamp: timestamp)
    populate_stats(site, events)
    :ok
  end

  def populate_stats(site, import_id, events) do
    Enum.map(events, fn event ->
      event = Map.put(event, :site_id, site.id)

      case event do
        %{_factory_event: true} ->
          event

        imported_event ->
          Map.put(imported_event, :import_id, import_id)
      end
    end)
    |> populate_stats
  end

  def populate_stats(site, events) do
    Enum.map(events, fn event ->
      Map.put(event, :site_id, site.id)
    end)
    |> populate_stats
  end

  def populate_stats(events) do
    {native, imported} =
      events
      |> Enum.map(fn event ->
        case event do
          %{timestamp: timestamp} ->
            %{event | timestamp: to_naive_truncate(timestamp)}

          _other ->
            event
        end
      end)
      |> Enum.split_with(fn event ->
        case event do
          %{_factory_event: true} ->
            true

          _ ->
            false
        end
      end)

    populate_native_stats(native)
    populate_imported_stats(imported)
  end

  defp populate_native_stats(events) do
    sessions =
      Enum.reduce(events, %{}, fn event, sessions ->
        session_id = Plausible.Session.CacheStore.on_event(event, session_params(event), nil)
        Map.put(sessions, {event.site_id, event.user_id}, session_id)
      end)

    Enum.each(events, fn event ->
      clickhouse_event =
        %Plausible.ClickhouseEventV2{}
        |> Map.merge(event)
        |> Map.put(:session_id, sessions[{event.site_id, event.user_id}])

      Plausible.Event.WriteBuffer.insert(clickhouse_event)
    end)

    Plausible.Session.WriteBuffer.flush()
    Plausible.Event.WriteBuffer.flush()
  end

  defp populate_imported_stats(events) do
    Enum.group_by(events, &Map.fetch!(&1, :table), &Map.delete(&1, :table))
    |> Enum.map(fn {table, events} -> Plausible.Imported.Buffer.insert_all(table, events) end)
  end

  @old_session_attributes [
    :referrer,
    :referrer_source,
    :utm_medium,
    :utm_source,
    :utm_campaign,
    :utm_content,
    :utm_term,
    :country_code,
    :subdivision1_code,
    :subdivision2_code,
    :city_geoname_id,
    :screen_size,
    :operating_system,
    :operating_system_version,
    :browser,
    :browser_version
  ]

  defp session_params(event) do
    event
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      str_key = Atom.to_string(key)

      cond do
        String.starts_with?(str_key, "session_") and key != :session_id ->
          session_key =
            str_key
            |> String.trim("session_")
            |> String.to_existing_atom()

          Map.put(acc, session_key, value)

        Enum.member?(@old_session_attributes, key) ->
          # :KLUDGE: Callsites should not use :referrer, etc directly and instead
          # use session_referrer: "foo". This is left here  for backwards compatibility
          # and to avoid breaking too many PRs.
          Map.put(acc, key, value)

        true ->
          acc
      end
    end)
  end

  def relative_time(shifts) do
    NaiveDateTime.utc_now()
    |> Timex.shift(shifts)
    |> NaiveDateTime.truncate(:second)
  end

  def to_naive_truncate(%DateTime{} = dt) do
    to_naive_truncate(DateTime.to_naive(dt))
  end

  def to_naive_truncate(%NaiveDateTime{} = naive) do
    NaiveDateTime.truncate(naive, :second)
  end

  def to_naive_truncate(%Date{} = date) do
    NaiveDateTime.new!(date, ~T[00:00:00])
  end

  def eventually(expectation, wait_time_ms \\ 50, retries \\ 10) do
    Enum.reduce_while(1..retries, nil, fn attempt, _acc ->
      case expectation.() do
        {true, result} ->
          {:halt, result}

        {false, _} ->
          Process.sleep(wait_time_ms * attempt)
          {:cont, nil}
      end
    end)
  end

  def await_clickhouse_count(query, expected) do
    eventually(
      fn ->
        count = Plausible.ClickhouseRepo.aggregate(query, :count)

        {count == expected, count}
      end,
      200,
      10
    )
  end

  def random_ip() do
    Enum.map_join(1..4, ".", fn _ -> Enum.random(1..254) end)
  end
end
