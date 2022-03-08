defmodule Plausible.SiteAdmin do
  use Plausible.Repo
  import Ecto.Query

  def search_fields(_schema) do
    [
      :domain,
      members: [:name, :email]
    ]
  end

  def custom_index_query(_conn, _schema, query) do
    from(r in query, preload: [memberships: :user])
  end

  def form_fields(_) do
    [
      domain: nil,
      timezone: nil,
      public: nil
    ]
  end

  def index(_) do
    [
      domain: nil,
      inserted_at: %{name: "Created at", value: &format_date(&1.inserted_at)},
      timezone: nil,
      public: nil,
      owner: %{value: &get_owner_email/1},
      other_members: %{value: &get_other_members_emails/1}
    ]
  end

  def list_actions(_conn) do
    [
      transfer_data: %{
        name: "Transfer data",
        inputs: [
          %{name: "domain", title: "domain", default: nil},
          %{name: "from", title: "From date YYYY-MM-DD", default: nil},
          %{name: "to", title: "To date YYYY-MM-DD", default: nil}
        ],
        action: fn _conn, sites, params -> transfer_data(sites, params) end
      }
    ]
  end

  defp transfer_data([site], params) do
    from_domain = site.domain
    to_domain = params["domain"]
    if domain_exists?(to_domain) do
      #transfer_sessions(from_domain, to_domain)
      transfer_events(from_domain, to_domain)
    else
      {:error, "Cannot transfer to non-existing domain"}
    end
  end

  defp transfer_data(_, _), do: {:error, "Please select exactly one site for this action"}

  defp transfer_sessions(from_domain, to_domain) do
    sql = "INSERT INTO sessions (session_id, sign, domain, user_id, hostname, timestamp, start, is_bounce, entry_page, exit_page, pageviews, events, duration, referrer, referrer_source, country_code, subdivision1_code, subdivision2_code, city_geoname_id, screen_size, operating_system, browser, utm_medium, utm_source, utm_campaign, utm_content, utm_term) SELECT session_id, sign, '#{to_domain}' as domain, user_id, hostname, timestamp, start, is_bounce, entry_page, exit_page, pageviews, events, duration, referrer, referrer_source, country_code, subdivision1_code, subdivision2_code, city_geoname_id, screen_size, operating_system, browser, utm_medium, utm_source, utm_campaign, utm_content, utm_term FROM (SELECT * FROM sessions WHERE domain='#{from_domain}')"
    Ecto.Adapters.SQL.query(Plausible.ClickhouseRepo, sql)
  end

  defp transfer_events(from_domain, to_domain) do
    sql = "INSERT INTO events (timestamp, name, domain, user_id, session_id, hostname, pathname, referrer, referrer_source, country_code, subdivision1_code, subdivision2_code, city_geoname_id, screen_size, operating_system, browser, meta.key, meta.value, utm_medium, utm_source, utm_campaign, utm_content, utm_term) SELECT timestamp, name, '#{to_domain}' as domain, user_id, session_id, hostname, pathname, referrer, referrer_source, country_code, subdivision1_code, subdivision2_code, city_geoname_id, screen_size, operating_system, browser, meta.key, meta.value, utm_medium, utm_source, utm_campaign, utm_content, utm_term FROM (SELECT * FROM events WHERE domain='#{from_domain}')"
    IO.inspect(sql)
    Ecto.Adapters.SQL.query(Plausible.ClickhouseRepo, sql)
  end

  defp get_owner_email(site) do
    Enum.find(site.memberships, fn m -> m.role == :owner end).user.email
  end

  defp get_other_members_emails(site) do
    memberships = Enum.reject(site.memberships, fn m -> m.role == :owner end)
    Enum.map(memberships, fn m -> m.user.email end) |> Enum.join(", ")
  end

  defp domain_exists?(domain) do
    Repo.exists?(from s in Plausible.Site, where: s.domain == ^domain)
  end

  defp format_date(date) do
    Timex.format!(date, "{Mshort} {D}, {YYYY}")
  end
end
