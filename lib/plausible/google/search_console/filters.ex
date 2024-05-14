defmodule Plausible.Google.SearchConsole.Filters do
  @moduledoc false
  import Plausible.Stats.Base, only: [page_regex: 1]

  def transform(property, plausible_filters) do
    plausible_filters = Map.drop(plausible_filters, ["visit:source"])

    search_console_filters =
      Enum.reduce_while(plausible_filters, [], fn plausible_filter, search_console_filters ->
        case transform_filter(property, plausible_filter) do
          :unsupported -> {:halt, :unsupported_filters}
          search_console_filter -> {:cont, [search_console_filter | search_console_filters]}
        end
      end)

    case search_console_filters do
      :unsupported_filters -> :unsupported_filters
      [] -> {:ok, []}
      filters when is_list(filters) -> {:ok, [%{filters: filters}]}
    end
  end

  defp transform_filter(property, {"event:page", filter}) do
    transform_filter(property, {"visit:entry_page", filter})
  end

  defp transform_filter(property, {"visit:entry_page", {:is, page}}) when is_binary(page) do
    %{dimension: "page", expression: property_url(property, page)}
  end

  defp transform_filter(property, {"visit:entry_page", {:member, pages}}) when is_list(pages) do
    expression =
      Enum.map_join(pages, "|", fn page -> property_url(property, Regex.escape(page)) end)

    %{dimension: "page", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(property, {"visit:entry_page", {:matches, page}}) when is_binary(page) do
    page = page_regex(property_url(property, page))
    %{dimension: "page", operator: "includingRegex", expression: page}
  end

  defp transform_filter(property, {"visit:entry_page", {:matches_member, pages}})
       when is_list(pages) do
    expression =
      Enum.map_join(pages, "|", fn page -> page_regex(property_url(property, page)) end)

    %{dimension: "page", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(_property, {"visit:screen", {:is, device}}) when is_binary(device) do
    %{dimension: "device", expression: search_console_device(device)}
  end

  defp transform_filter(_property, {"visit:screen", {:member, devices}}) when is_list(devices) do
    expression = devices |> Enum.join("|")
    %{dimension: "device", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(_property, {"visit:country", {:is, country}}) when is_binary(country) do
    %{dimension: "country", expression: search_console_country(country)}
  end

  defp transform_filter(_property, {"visit:country", {:member, countries}})
       when is_list(countries) do
    expression = Enum.map_join(countries, "|", &search_console_country/1)
    %{dimension: "country", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(_, _filter), do: :unsupported

  defp property_url("sc-domain:" <> domain, page), do: "https://" <> domain <> page
  defp property_url(url, page), do: url <> page

  defp search_console_device("Desktop"), do: "DESKTOP"
  defp search_console_device("Mobile"), do: "MOBILE"
  defp search_console_device("Tablet"), do: "TABLET"

  defp search_console_country(alpha_2) do
    country = Location.Country.get_country(alpha_2)
    country.alpha_3
  end
end
