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
        domain: "test-site.com",
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
        Factory.build(:pageview, pageview)
        |> Map.from_struct()
        |> Map.delete(:__meta__)
        |> update_in([:timestamp], &to_naive_truncate/1)
      end)

    Plausible.IngestRepo.insert_all(Plausible.ClickhouseEvent, pageviews)
  end

  def create_events(events) do
    events =
      Enum.map(events, fn event ->
        Factory.build(:event, event)
        |> Map.from_struct()
        |> Map.delete(:__meta__)
        |> update_in([:timestamp], &to_naive_truncate/1)
      end)

    Plausible.IngestRepo.insert_all(Plausible.ClickhouseEvent, events)
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

    Plausible.IngestRepo.insert_all(Plausible.ClickhouseSession, sessions)
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

  def populate_stats(site, events) do
    Enum.map(events, fn event ->
      case event do
        %Plausible.ClickhouseEvent{} ->
          Map.put(event, :domain, site.domain)

        _ ->
          Map.put(event, :site_id, site.id)
      end
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
          %Plausible.ClickhouseEvent{} ->
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
        session_id = Plausible.Session.CacheStore.on_event(event, nil)
        Map.put(sessions, {event.domain, event.user_id}, session_id)
      end)

    Enum.each(events, fn event ->
      event = Map.put(event, :session_id, sessions[{event.domain, event.user_id}])
      Plausible.Event.WriteBuffer.insert(event)
    end)

    Plausible.Session.WriteBuffer.flush()
    Plausible.Event.WriteBuffer.flush()
  end

  defp populate_imported_stats(events) do
    Enum.group_by(events, &Map.fetch!(&1, :table), &Map.delete(&1, :table))
    |> Enum.map(fn {table, events} -> Plausible.Google.Buffer.insert_all(table, events) end)
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
end
