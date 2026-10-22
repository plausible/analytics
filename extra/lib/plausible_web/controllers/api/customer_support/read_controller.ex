defmodule PlausibleWeb.Api.CustomerSupport.ReadController do
  @moduledoc """
  Read-only lookups for the support automation, limited to what its other
  data source (Metabase, on a read replica) doesn't have: pageview usage per
  billing cycle and features used, a team's audit log, and email
  suppressions. Teams, members, sites, subscriptions and plans are read from
  Metabase.
  """
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias PlausibleWeb.Api.CustomerSupport.Helpers, as: H

  @audit_page_size 50

  @doc "Pageviews per billing cycle, member and site counts, and features used."
  def team_usage(conn, %{"team_id" => team_id}) do
    case H.fetch_team(team_id) do
      {:ok, team} -> json(conn, %{usage: usage_json(team)})
      error -> H.respond_error(conn, error)
    end
  end

  def team_audit(conn, %{"team_id" => team_id}) do
    case H.fetch_team(team_id) do
      {:ok, team} -> json(conn, %{entries: audit_json(team)})
      error -> H.respond_error(conn, error)
    end
  end

  def email_suppression(conn, %{"email" => email}) when is_binary(email) do
    suppression = H.fetch_suppression(email)

    json(conn, %{
      suppression:
        suppression &&
          Map.take(suppression, [
            :email,
            :reason,
            :source,
            :details,
            :can_activate,
            :postmark_inactive,
            :reactivated_at
          ])
    })
  end

  def email_suppression(conn, _params) do
    PlausibleWeb.Api.Helpers.bad_request(conn, "Parameter `email` is required")
  end

  defp usage_json(team) do
    usage = Plausible.Teams.Billing.quota_usage(team, with_features: true)

    pageviews =
      Map.new(usage.monthly_pageviews, fn {cycle, cycle_usage} ->
        {cycle,
         %{
           from: cycle_usage.date_range.first,
           to: cycle_usage.date_range.last,
           total: cycle_usage.total
         }}
      end)

    %{
      monthly_pageviews: pageviews,
      team_members: usage.team_members,
      sites: usage.sites,
      features_used: Enum.map(usage.features, &Atom.to_string(&1.name()))
    }
  end

  defp audit_json(team) do
    entries =
      Repo.all(
        from e in Plausible.Audit.Entry,
          where: e.team_id == ^team.id,
          order_by: [desc: e.datetime],
          limit: @audit_page_size
      )

    Enum.map(
      entries,
      &Map.take(&1, [:name, :entity, :entity_id, :user_id, :actor_type, :datetime, :meta])
    )
  end
end
