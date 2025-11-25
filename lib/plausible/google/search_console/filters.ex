defmodule Plausible.Google.SearchConsole.Filters do
  @moduledoc false
  import Plausible.Stats.Filters.Utils, only: [page_regex: 1]

  def transform(property, plausible_filters, search) do
    gsc_filters =
      Enum.reduce_while(plausible_filters, [], fn plausible_filter, gsc_filters ->
        case transform_filter(property, plausible_filter) do
          :unsupported -> {:halt, :unsupported_filters}
          :ignore -> {:cont, gsc_filters}
          gsc_filter -> {:cont, [gsc_filter | gsc_filters]}
        end
      end)
      |> maybe_add_search_filter(search)

    case gsc_filters do
      :unsupported_filters -> :unsupported_filters
      [] -> {:ok, []}
      filters when is_list(filters) -> {:ok, [%{filters: filters}]}
    end
  end

  defp transform_filter(property, [op, "event:page" | rest]) do
    transform_filter(property, [op, "visit:entry_page" | rest])
  end

  # :TODO: Should also work case-insensitive, if not, blacklist.
  defp transform_filter(property, [:is, "visit:entry_page", pages | _]) when is_list(pages) do
    expression =
      Enum.map_join(pages, "|", fn page -> property_url(property, Regex.escape(page)) end)

    %{dimension: "page", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(property, [:matches_wildcard, "visit:entry_page", pages | _])
       when is_list(pages) do
    expression =
      Enum.map_join(pages, "|", fn page -> page_regex(property_url(property, page)) end)

    %{dimension: "page", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(_property, [:is, "visit:screen", devices | _]) when is_list(devices) do
    expression = Enum.map_join(devices, "|", &search_console_device/1)
    %{dimension: "device", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(_property, [:is, "visit:country", countries | _])
       when is_list(countries) do
    expression = Enum.map_join(countries, "|", &search_console_country/1)
    %{dimension: "country", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(_, [_, "visit:source" | _rest]), do: :ignore

  defp transform_filter(_, [_, "visit:channel" | _rest]), do: :ignore

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

  defp maybe_add_search_filter(gsc_filters, search) when byte_size(search) > 0 do
    [%{operator: "includingRegex", expression: search, dimension: "query"} | gsc_filters]
  end

  defp maybe_add_search_filter(gsc_filters, _search), do: gsc_filters
end
