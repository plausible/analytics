defmodule Plausible.TestUtils do
  use Plausible.Repo
  alias Plausible.Factory

  def create_user(_) do
    {:ok, user: Factory.insert(:user)}
  end

  def create_site(%{user: user}) do
    site = Factory.insert(:site, domain: "test-site.com", members: [user])
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
        Factory.build(:pageview, pageview) |> Map.from_struct() |> Map.delete(:__meta__)
      end)

    Plausible.ClickhouseRepo.insert_all("events", pageviews)
  end

  def create_events(events) do
    events =
      Enum.map(events, fn event ->
        Factory.build(:event, event) |> Map.from_struct() |> Map.delete(:__meta__)
      end)

    Plausible.ClickhouseRepo.insert_all("events", events)
  end

  def create_sessions(sessions) do
    sessions =
      Enum.map(sessions, fn session ->
        Factory.build(:ch_session, session) |> Map.from_struct() |> Map.delete(:__meta__)
      end)

    Plausible.ClickhouseRepo.insert_all("sessions", sessions)
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
      Enum.split_with(events, fn event ->
        case event do
          %Plausible.ClickhouseEvent{} ->
            true

          _ ->
            false
        end
      end)

    if native, do: populate_native_stats(native)
    if imported, do: populate_imported_stats(imported)
  end

  defp populate_native_stats(events) do
    sessions =
      Enum.reduce(events, %{}, fn event, sessions ->
        Plausible.Session.Store.reconcile_event(sessions, event)
      end)

    events =
      Enum.map(events, fn event ->
        Map.put(event, :session_id, sessions[{event.domain, event.user_id}].session_id)
      end)

    Plausible.ClickhouseRepo.insert_all(
      Plausible.ClickhouseEvent,
      Enum.map(events, &schema_to_map/1)
    )

    Plausible.ClickhouseRepo.insert_all(
      Plausible.ClickhouseSession,
      Enum.map(Map.values(sessions), &schema_to_map/1)
    )
  end

  defp populate_imported_stats(events) do
    Enum.group_by(events, &Map.fetch!(&1, :table), &Map.delete(&1, :table))
    |> Enum.map(fn {table, events} -> Plausible.ClickhouseRepo.insert_all(table, events) end)
  end

  def relative_time(shifts) do
    NaiveDateTime.utc_now()
    |> Timex.shift(shifts)
    |> NaiveDateTime.truncate(:second)
  end

  defp schema_to_map(schema) do
    Map.from_struct(schema)
    |> Map.delete(:__meta__)
  end
end
