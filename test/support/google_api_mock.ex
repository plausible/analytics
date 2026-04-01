defmodule Plausible.Google.API.Mock do
  @moduledoc """
  Mock of API to Google services.
  """

  @doc """
  This function uses the event:page filter (which can be passed as a query
  parameter into StatsController) as a hack to mock different responses.
  """
  def fetch_stats(_auth, query, _pagination, _search) do
    case page_filter_value(query) do
      ["/empty"] ->
        {:ok, []}

      ["/unsupported-filters"] ->
        {:error, :unsupported_filters}

      ["/not-configured"] ->
        {:error, :google_property_not_configured}

      ["/unexpected-error"] ->
        {:error, :some_unexpected_error}

      _ ->
        {:ok,
         [
           %{
             name: "simple web analytics",
             visitors: 25,
             impressions: 50,
             ctr: 37.0,
             position: 2.0
           },
           %{
             name: "open-source analytics",
             visitors: 15,
             impressions: 25,
             ctr: 50.0,
             position: 4.0
           }
         ]}
    end
  end

  defp page_filter_value(query) do
    Enum.find_value(query.filters, fn
      [:is, "event:page", value] -> value
      _ -> nil
    end)
  end
end
