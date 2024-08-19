defmodule PlausibleWeb.EmailView do
  use Plausible
  use PlausibleWeb, :view

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def greet_recipient(%{user: %{name: name}}) when is_binary(name) do
    "Hey #{String.split(name) |> List.first()},"
  end

  def greet_recipient(_), do: "Hey,"

  def date_format(date) do
    Calendar.strftime(date, "%-d %b %Y")
  end

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
