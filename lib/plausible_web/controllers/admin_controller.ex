defmodule PlausibleWeb.AdminController do
  use PlausibleWeb, :controller

  alias Plausible.Billing.Quota

  def usage(conn, params) do
    user =
      params["user_id"]
      |> String.to_integer()
      |> Plausible.Users.with_subscription()

    usage = Quota.usage(user, with_features: true)

    limits = %{
      monthly_pageviews: Quota.monthly_pageview_limit(user),
      sites: Quota.site_limit(user),
      team_members: Quota.team_member_limit(user)
    }

    html_response = usage_and_limits_html(user, usage, limits)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html_response)
  end

  defp usage_and_limits_html(user, usage, limits) do
    """
    <!DOCTYPE html>
    <html lang="en">

    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Usage - user:#{user.id}</title>
      <style>
        ul, li {margin-top: 10px;}
        body {padding-top: 10px;}
      </style>
    </head>

    <body>
      <ul>
        <li>Sites: <b>#{usage.sites}</b> / #{limits.sites}</li>
        <li>Team members: <b>#{usage.team_members}</b> / #{limits.team_members}</li>
        <li>Features: #{features_usage(usage.features)}</li>
        <li>Monthly pageviews: #{monthly_pageviews_usage(usage.monthly_pageviews, limits.monthly_pageviews)}</li>
      </ul>
    </body>

    </html>
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
end
