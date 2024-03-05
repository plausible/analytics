defmodule Plausible.TestUtils do
  use Plausible.Repo
  alias Plausible.Factory

  require Logger

  defmacro __using__(_) do
    quote do
      require Plausible.TestUtils
      import Plausible.TestUtils
      use Plausible.Test.Support.Journey
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
        |> Map.from_struct()
        |> Map.delete(:__meta__)
        |> update_in([:timestamp], &to_naive_truncate/1)
      end)

    Plausible.IngestRepo.insert_all(Plausible.ClickhouseEventV2, pageviews)
  end

  def create_events(events) do
    events =
      Enum.map(events, fn event ->
        Factory.build(:event, event)
        |> Map.from_struct()
        |> Map.delete(:__meta__)
        |> update_in([:timestamp], &to_naive_truncate/1)
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
        %Plausible.ClickhouseEventV2{} ->
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
          %Plausible.ClickhouseEventV2{} ->
            true

          _ ->
            false
        end
      end)

    populate_native_stats(native)
    populate_imported_stats(imported)
  end

  defp populate_native_stats(events) do
    for event_params <- events do
      session = Plausible.Session.CacheStore.on_event(event_params, event_params, nil)

      event_params
      |> Map.merge(session)
      |> Plausible.Event.WriteBuffer.insert()
    end

    Plausible.Session.WriteBuffer.flush()
    Plausible.Event.WriteBuffer.flush()
  end

  defp populate_imported_stats(events) do
    Enum.group_by(events, &Map.fetch!(&1, :table), &Map.delete(&1, :table))
    |> Enum.map(fn {table, events} -> Plausible.Imported.Buffer.insert_all(table, events) end)
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

  def random_ipv6() do
    <<a1::16, a2::16, a3::16, a4::16, a5::16, a6::16, a7::16, a8::16>> =
      :crypto.strong_rand_bytes(16)

    [a1, a2, a3, a4, a5, a6, a7, a8]
    |> Enum.map_join(":", &Base.encode16(<<&1>>, case: :lower))
  end

  def tomorrow(now) do
    NaiveDateTime.add(now, 1, :day)
  end

  def rand_user_agent() do
    [
      "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) GSA/156.1.368858699 Mobile/18A393 Safari/604.1",
      "Mozilla/5.0 (Linux; Android 9; SM-A305G Build/PPR1.180610.011; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/90.0.4430.82 Mobile Safari/537.36 GSA/12.14.7.23.arm64",
      "Mozilla/5.0 (Linux; Android 10; moto g(8) plus Build/QPIS30.28-Q3-28-26-3-4; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/90.0.4430.66 Mobile Safari/537.36 GSA/12.14.7.23.arm64",
      "com.google.GoogleMobile/156.1 iPhone/14.0.1 hw/iPhone10_4",
      "Mozilla/5.0 (Linux; Android 10; vivo 1819 Build/QP1A.190711.020; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/90.0.4430.66 Mobile Safari/537.36 GSA/12.14.7.23.arm64",
      "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.2; Win64; x64; Trident/7.0; .NET4.0C; .NET4.0E; InfoPath.3; Tablet PC 2.0; HCTE; ms-office; MSOffice 15)",
      "Mozilla/5.0 (Linux; Android 5.1; F5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.181 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 9; LM-X420 Build/PKQ1.190522.001; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/90.0.4430.66 Mobile Safari/537.36 GSA/12.14.7.23.arm",
      "Mozilla/5.0 (Linux; Android 10; SM-A516B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.82 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 7.0; Mi-4c) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.66 Mobile Safari/537.36"
    ]
    |> Enum.random()
  end

  def rand_idle(_), do: Enum.random(1..100)
end
