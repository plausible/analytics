defmodule PlausibleWeb.AdminController do
  use PlausibleWeb, :controller

  alias Plausible.Teams

  alias PlausibleWeb.Router.Helpers, as: Routes

  def usage(conn, params) do
    user_id = String.to_integer(params["user_id"])

    team =
      case Teams.get_by_owner(user_id) do
        {:ok, team} ->
          team
          |> Teams.with_subscription()
          |> Plausible.Repo.preload(:owner)

        {:error, :no_team} ->
          nil
      end

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

  def current_plan(conn, params) do
    user_id = String.to_integer(params["user_id"])

    team =
      case Teams.get_by_owner(user_id) do
        {:ok, team} ->
          Teams.with_subscription(team)

        {:error, :no_team} ->
          nil
      end

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

  defp usage_and_limits_html(team, usage, limits, embed?) do
    sites_row =
      if team do
        sites_count =
          team
          |> Ecto.assoc(:sites)
          |> Plausible.Repo.aggregate(:count)

        sites_link =
          Routes.kaffy_resource_url(PlausibleWeb.Endpoint, :index, :sites, :site,
            custom_search: team.owner.email
          )

        """
        <li>Owner of <a href="#{sites_link}">#{sites_count} site#{if sites_count != 1, do: "s", else: ""}</a></li>
        """
      else
        """
        <li>Owner of 0 sites</li>
        """
      end

    content = """
      <ul>
        <li>Team: <b>#{team && team.name}</b></li>
        <li>Sites: <b>#{usage.sites}</b> / #{limits.sites}</li>
        <li>Team members: <b>#{usage.team_members}</b> / #{limits.team_members}</li>
        <li>Features: #{features_usage(usage.features)}</li>
        <li>Monthly pageviews: #{monthly_pageviews_usage(usage.monthly_pageviews, limits.monthly_pageviews)}</li>
        #{sites_row}
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
end
