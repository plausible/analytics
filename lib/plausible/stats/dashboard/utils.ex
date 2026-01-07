defmodule Plausible.Stats.Dashboard.Utils do
  @moduledoc """
  Shared utilities by different dashboard reports.
  """

  alias Plausible.Site
  alias Plausible.Stats.{Dashboard, ParsedQueryParams}

  def page_external_link_fn_for(site) do
    with true <- Plausible.Sites.regular?(site),
         [domain | _] <- String.split(site.domain, "/"),
         {:ok, domain} <- idna_encode(domain),
         {:ok, uri} <- URI.new("https://#{domain}/") do
      fn item ->
        "https://#{uri.host}#{hd(item.dimensions)}"
      end
    else
      _ -> nil
    end
  end

  def dashboard_route(%Site{} = site, %ParsedQueryParams{} = params, opts) do
    path = Keyword.get(opts, :path, "")

    params =
      case Keyword.get(opts, :filter) do
        nil -> params
        filter -> ParsedQueryParams.add_or_replace_filter(params, filter)
      end

    query_string =
      case Dashboard.QuerySerializer.serialize(params) do
        "" -> ""
        query_string -> "?" <> query_string
      end

    "/" <> site.domain <> path <> query_string
  end

  defp idna_encode(domain) do
    try do
      {:ok, domain |> String.to_charlist() |> :idna.encode() |> IO.iodata_to_binary()}
    catch
      _ -> {:error, :invalid_domain}
    end
  end
end
