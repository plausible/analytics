defmodule Mix.Tasks.DownloadIpRegistries do
  @moduledoc """
  Refreshes the IANA special-purpose address registries used by
  `Plausible.IP.Tools` at compile time to recognize reserved/private IPs.
  """

  use Mix.Task
  require Logger

  alias Plausible.IP

  # coveralls-ignore-start

  @sources %{
    IP.Tools.Registry.ipv4_registry_path() =>
      "https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry-1.csv",
    IP.Tools.Registry.ipv6_registry_path() =>
      "https://www.iana.org/assignments/iana-ipv6-special-registry/iana-ipv6-special-registry-1.csv"
  }

  def run(_) do
    Application.ensure_all_started(:req)

    for {path, url} <- @sources do
      path |> Path.dirname() |> File.mkdir_p!()

      Logger.notice("Downloading #{url}")

      case Req.get(url) do
        {:ok, %{status: 200, body: body}} ->
          File.write!(path, body)
          Logger.notice("Saved #{path}")

        other ->
          Logger.error("Unable to download #{url}. Response: #{inspect(other)}")
      end
    end
  end
end
