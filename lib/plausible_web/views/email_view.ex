defmodule PlausibleWeb.EmailView do
  use Plausible
  use PlausibleWeb, :view

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def choose_plan_url(team) do
    PlausibleWeb.Router.Helpers.billing_url(PlausibleWeb.Endpoint, :choose_plan) <>
      "?__team=#{team.identifier}"
  end

  on_ee do
    def customer_support_team_url(team) do
      PlausibleWeb.Router.Helpers.customer_support_team_url(PlausibleWeb.Endpoint, :show, team.id)
    end
  else
    def customer_support_team_url(_team), do: nil
  end

  def format_pageview_limit(:unlimited), do: "unlimited"
  def format_pageview_limit(limit), do: PlausibleWeb.AuthView.delimit_integer(limit)

  def greet_recipient(%{user: %{name: name}}) when is_binary(name) do
    "Hey #{String.split(name) |> List.first()},"
  end

  def greet_recipient(_), do: "Hey,"

  def date_format(date) do
    Calendar.strftime(date, "%-d %b %Y")
  end

  def domains_list(domains, 0) do
    Enum.join(domains, ", ")
  end

  def domains_list(domains, more_count) do
    Enum.join(domains, ", ") <> " (and #{more_count} more #{pluralize_site(more_count)})"
  end

  defp pluralize_site(1), do: "site"
  defp pluralize_site(_), do: "sites"

  def sentry_link(trace_id, dsn \\ Sentry.Config.dsn()) do
    search_query = URI.encode_query(%{query: trace_id})
    path = "/organizations/sentry/issues/"

    if is_binary(dsn) do
      dsn
      |> URI.parse()
      |> Map.replace(:userinfo, nil)
      |> Map.replace(:path, path)
      |> Map.replace(:query, search_query)
      |> URI.to_string()
    else
      ""
    end
  end
end
