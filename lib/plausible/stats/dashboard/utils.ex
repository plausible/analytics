defmodule Plausible.Stats.Dashboard.Utils do
  @moduledoc """
  Shared utilities by different dashboard reports.
  """

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

  defp idna_encode(domain) do
    try do
      {:ok, domain |> String.to_charlist() |> :idna.encode() |> IO.iodata_to_binary()}
    catch
      _ -> {:error, :invalid_domain}
    end
  end
end
