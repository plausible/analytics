defmodule Plausible.SiteAdmin do
  use Plausible.Repo
  import Ecto.Query

  def ordering(_schema) do
    [desc: :inserted_at]
  end

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
      domain: %{update: :readonly},
      timezone: %{choices: Plausible.Timezones.options()},
      public: nil,
      stats_start_date: nil,
      ingest_rate_limit_scale_seconds: %{
        help_text: "Time scale for which events rate-limiting is calculated. Default: 60"
      },
      ingest_rate_limit_threshold: %{
        help_text:
          "Keep empty to disable rate limiting, set to 0 to bar all events. Any positive number sets the limit."
      }
    ]
  end

  def index(_) do
    [
      domain: nil,
      inserted_at: %{name: "Created at", value: &format_date(&1.inserted_at)},
      timezone: nil,
      public: nil,
      owner: %{value: &get_owner_email/1},
      other_members: %{value: &get_other_members/1},
      limits: %{
        value: fn site ->
          case site.ingest_rate_limit_threshold do
            nil -> ""
            0 -> "🛑 BLOCKED"
            n -> "⏱ #{n}/#{site.ingest_rate_limit_scale_seconds}s (per server)"
          end
        end
      }
    ]
  end

  def list_actions(_conn) do
    [
      transfer_data: %{
        name: "Transfer data",
        inputs: [
          %{name: "domain", title: "to domain", default: nil}
        ],
        action: fn _conn, sites, params -> transfer_data(sites, params) end
      }
    ]
  end

  defp format_date(date) do
    Timex.format!(date, "{Mshort} {D}, {YYYY}")
  end

  defp get_owner_email(site) do
    owner = Enum.find(site.memberships, fn m -> m.role == :owner end)

    if owner do
      owner.user.email
    end
  end

  defp get_other_members(site) do
    Enum.filter(site.memberships, &(&1.role != :owner))
    |> Enum.map(fn m -> m.user.email <> "(#{to_string(m.role)})" end)
    |> Enum.join(", ")
  end

  def transfer_data([from_site], params) do
    to_site = Repo.get_by(Plausible.Site, domain: params["domain"])

    if to_site do
      opts = [timeout: 30_000, command: :insert_select]

      event_q = event_transfer_query(from_site.domain, to_site.domain)
      {:ok, _} = Ecto.Adapters.SQL.query(Plausible.ClickhouseRepo, event_q, [], opts)

      session_q = session_transfer_query(from_site.domain, to_site.domain)
      {:ok, _} = Ecto.Adapters.SQL.query(Plausible.ClickhouseRepo, session_q, [], opts)

      start_date = Plausible.Stats.Clickhouse.pageview_start_date_local(from_site)

      {:ok, _} =
        to_site
        |> Plausible.Site.set_stats_start_date(start_date)
        |> Plausible.Site.set_native_stats_start_at(from_site.native_stats_start_at)
        |> Repo.update()

      :ok
    else
      {:error, "Cannot transfer to non-existing domain"}
    end
  end

  def transfer_data(_, _), do: {:error, "Please select exactly one site for this action"}

  def session_transfer_query(from_domain, to_domain) do
    fields = get_struct_fields(Plausible.ClickhouseSession)

    "INSERT INTO sessions (" <>
      stringify_fields(fields) <>
      ") SELECT " <>
      stringify_fields(fields, to_domain, from_domain) <>
      " FROM (SELECT * FROM sessions WHERE domain='#{from_domain}')"
  end

  def event_transfer_query(from_domain, to_domain) do
    fields = get_struct_fields(Plausible.ClickhouseEvent)

    "INSERT INTO events (" <>
      stringify_fields(fields) <>
      ") SELECT " <>
      stringify_fields(fields, to_domain, from_domain) <>
      " FROM (SELECT * FROM events WHERE domain='#{from_domain}')"
  end

  def get_struct_fields(module) do
    module.__struct__()
    |> Map.drop([:__meta__, :__struct__])
    |> Map.keys()
    |> Enum.map(&Atom.to_string/1)
    |> Enum.sort()
  end

  defp stringify_fields(fields), do: Enum.join(fields, ", ")

  defp stringify_fields(fields, domain_value, transferred_from_value) do
    Enum.map(fields, fn field ->
      case field do
        "domain" -> "'#{domain_value}' as domain"
        "transferred_from" -> "'#{transferred_from_value}' as transferred_from"
        _ -> field
      end
    end)
    |> stringify_fields()
  end

  def create_changeset(schema, attrs), do: Plausible.Site.crm_changeset(schema, attrs)
  def update_changeset(schema, attrs), do: Plausible.Site.crm_changeset(schema, attrs)
end
