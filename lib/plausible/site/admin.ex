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
    Enum.find(site.memberships, fn m -> m.role == :owner end).user.email
  end

  defp get_other_members_emails(site) do
    memberships = Enum.reject(site.memberships, fn m -> m.role == :owner end)
    Enum.map(memberships, fn m -> m.user.email end) |> Enum.join(", ")
  end

  def transfer_data([site], params) do
    from_domain = site.domain
    to_domain = params["domain"]

    if to_domain && domain_exists?(to_domain) do
      event_q = event_transfer_query(from_domain, to_domain)
      {:ok, _} = Ecto.Adapters.SQL.query(Plausible.ClickhouseRepo, event_q)

      session_q = session_transfer_query(from_domain, to_domain)
      {:ok, _} = Ecto.Adapters.SQL.query(Plausible.ClickhouseRepo, session_q)

      :ok
    else
      {:error, "Cannot transfer to non-existing domain"}
    end
  end

  def transfer_data(_, _), do: {:error, "Please select exactly one site for this action"}

  defp domain_exists?(domain) do
    Repo.exists?(from s in Plausible.Site, where: s.domain == ^domain)
  end

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
end
