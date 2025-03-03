defmodule PlausibleWeb.AdminController do
  use PlausibleWeb, :controller
  use Plausible

  import Ecto.Query

  alias Plausible.Repo
  alias Plausible.Teams

  def usage(conn, params) do
    team_id = String.to_integer(params["team_id"])

    team =
      team_id
      |> Teams.get()
      |> Repo.preload([:owners, team_memberships: :user])
      |> Teams.with_subscription()

    usage = Teams.Billing.quota_usage(team, with_features: true)

    limits = %{
      monthly_pageviews: Teams.Billing.monthly_pageview_limit(team),
      sites: Teams.Billing.site_limit(team),
      team_members: Teams.Billing.team_member_limit(team)
    }

    html_response = usage_and_limits_html(team, usage, limits, params["embed"] == "true")

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html_response)
  end

  def user_info(conn, params) do
    user_id = String.to_integer(params["user_id"])

    user =
      Plausible.Auth.User
      |> Repo.get!(user_id)
      |> Repo.preload(:owned_teams)

    teams_list = Plausible.Auth.UserAdmin.teams(user.owned_teams)

    html_response = """
      <div style="margin-bottom: 1.1em;">
        <p><b>Owned teams:</b></p>
        #{teams_list}
      </div>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html_response)
  end

  def current_plan(conn, params) do
    team_id = String.to_integer(params["team_id"])

    team =
      team_id
      |> Teams.get()
      |> Teams.with_subscription()

    plan =
      case team && team.subscription &&
             Plausible.Billing.Plans.get_subscription_plan(team.subscription) do
        %{} = plan ->
          plan
          |> Map.take([
            :billing_interval,
            :monthly_pageview_limit,
            :site_limit,
            :team_member_limit,
            :hourly_api_request_limit,
            :features
          ])
          |> Map.update(:features, [], fn features -> Enum.map(features, & &1.name()) end)

        _ ->
          %{features: []}
      end

    json_response = Jason.encode!(plan)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json_response)
  end

  def team_by_id(conn, params) do
    id = params["team_id"]

    entry =
      Repo.one(
        from t in Plausible.Teams.Team,
          inner_join: o in assoc(t, :owners),
          where: t.id == ^id,
          group_by: t.id,
          select:
            fragment(
              """
              case when ? = ? then 
                string_agg(concat(?, ' (', ?, ')'), ',') 
              else 
                concat(?, ' [', string_agg(concat(?, ' (', ?, ')'), ','), ']') 
              end
              """,
              t.name,
              ^Plausible.Teams.default_name(),
              o.name,
              o.email,
              t.name,
              o.name,
              o.email
            )
      ) || ""

    conn
    |> send_resp(200, entry)
  end

  def team_search(conn, params) do
    search =
      (params["search"] || "")
      |> String.trim()

    choices =
      if search != "" do
        term =
          search
          |> String.replace("%", "\%")
          |> String.replace("_", "\_")

        term = "%#{term}%"

        team_id =
          case Integer.parse(search) do
            {id, ""} -> id
            _ -> 0
          end

        if team_id != 0 do
          []
        else
          Repo.all(
            from t in Teams.Team,
              inner_join: o in assoc(t, :owners),
              where:
                t.id == ^team_id or
                  type(t.identifier, :string) == ^search or
                  ilike(t.name, ^term) or
                  ilike(o.email, ^term) or
                  ilike(o.name, ^term),
              order_by: [t.name, t.id],
              group_by: t.id,
              select: [
                fragment(
                  """
                  case when ? = ? then 
                    concat(string_agg(concat(?, ' (', ?, ')'), ','), ' - ', ?)
                  else 
                    concat(concat(?, ' [', string_agg(concat(?, ' (', ?, ')'), ','), ']'), ' - ', ?)
                  end
                  """,
                  t.name,
                  ^Plausible.Teams.default_name(),
                  o.name,
                  o.email,
                  t.identifier,
                  t.name,
                  o.name,
                  o.email,
                  t.identifier
                ),
                t.id
              ],
              limit: 20
          )
        end
      else
        []
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(choices))
  end

  defp usage_and_limits_html(team, usage, limits, embed?) do
    content = """
      <ul>
        <li>Team: <b>#{team.name}</b></li>
        <li>Subscription plan: #{Teams.TeamAdmin.subscription_plan(team)}</li>
        <li>Subscription status: #{Teams.TeamAdmin.subscription_status(team)}</li>
        <li>Grace period: #{Teams.TeamAdmin.grace_period_status(team)}</li>
        <li>Sites: <b>#{usage.sites}</b> / #{limits.sites}</li>
        <li>Team members: <b>#{usage.team_members}</b> / #{limits.team_members}</li>
        <li>Features: #{features_usage(usage.features)}</li>
        <li>Monthly pageviews: #{monthly_pageviews_usage(usage.monthly_pageviews, limits.monthly_pageviews)}</li>
        #{sites_count_row(team)}
        <li>Owners: #{get_owners(team)}</li>
        <li>Team members: #{get_other_members(team)}</li>
      </ul>
    """

    if embed? do
      content
    else
      """
      <!DOCTYPE html>
      <html lang="en">

      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Usage - team:#{team && team.id}</title>
        <style>
          ul, li {margin-top: 10px;}
          body {padding-top: 10px;}
        </style>
      </head>

      <body>
        #{content}
      </body>

      </html>
      """
    end
  end

  on_ee do
    alias PlausibleWeb.Router.Helpers, as: Routes

    defp sites_count_row(%Plausible.Teams.Team{} = team) do
      sites_count =
        team
        |> Ecto.assoc(:sites)
        |> Plausible.Repo.aggregate(:count)

      sites_link =
        Routes.kaffy_resource_url(PlausibleWeb.Endpoint, :index, :sites, :site,
          custom_search: team.identifier
        )

      """
      <li>Owner of <a href="#{sites_link}">#{sites_count} site#{if sites_count != 1, do: "s", else: ""}</a></li>
      """
    end
  end

  defp sites_count_row(_) do
    """
    <li>Owner of 0 sites</li>
    """
  end

  defp features_usage(features_module_list) do
    list_items =
      features_module_list
      |> Enum.map_join(fn f_mod -> "<li>#{f_mod.display_name()}</li>" end)

    "<ul>#{list_items}</ul>"
  end

  defp monthly_pageviews_usage(usage, limit) do
    list_items =
      usage
      |> Enum.sort_by(fn {_cycle, usage} -> usage.date_range.first end, :desc)
      |> Enum.map(fn {cycle, usage} ->
        "<li>#{cycle} (#{PlausibleWeb.TextHelpers.format_date_range(usage.date_range)}): <b>#{usage.total}</b> / #{limit}</li>"
      end)

    "<ul>#{Enum.join(list_items)}</ul>"
  end

  defp get_owners(team) do
    team.owners
    |> Enum.map_join(", ", fn owner ->
      email = html_escape(owner.email)

      """
      <a href="/crm/auth/user/#{owner.id}">#{email}</a>
      """
    end)
  end

  defp get_other_members(team) do
    team.team_memberships
    |> Enum.reject(&(&1.role == :owner))
    |> Enum.map_join(", ", fn tm ->
      email = html_escape(tm.user.email)
      role = html_escape(tm.role)

      """
      <a href="/crm/auth/user/#{tm.user.id}">#{email <> " (#{role})"}</a>
      """
    end)
  end

  def html_escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
