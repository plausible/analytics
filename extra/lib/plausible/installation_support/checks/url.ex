defmodule Plausible.InstallationSupport.Checks.Url do
  @moduledoc """
  Checks if site domain resolves (either A or AAAA record) to a public address.
  If not, checks if prepending `www.` helps, because we have specifically 
  requested customers to register the domain with `www.` prefix.

  If not, skips all further checks.
  """

  use Plausible.InstallationSupport.Check

  @impl true
  def report_progress_as, do: "We're trying to reach your website"

  @impl true
  @spec perform(State.t(), Keyword.t()) :: State.t()
  def perform(%State{url: url} = state, _opts) when is_binary(url) do
    with {:ok, %URI{scheme: scheme} = uri} when scheme in ["http", "https"] <- URI.new(url),
         :ok <- dns_lookup(uri.host) do
      stripped_url = URI.to_string(%URI{uri | query: nil, fragment: nil})
      %State{state | url: stripped_url}
    else
      {:error, :resolve_host_error} ->
        put_diagnostics(%State{state | skip_further_checks?: true},
          service_error: %{code: :domain_not_found}
        )

      _ ->
        put_diagnostics(%State{state | skip_further_checks?: true},
          service_error: %{code: :invalid_url}
        )
    end
  end

  def perform(%State{data_domain: domain} = state, _opts) when is_binary(domain) do
    case find_working_url(domain) do
      {:ok, working_url} ->
        %State{state | url: working_url}

      {:error, :domain_not_found} ->
        put_diagnostics(%State{state | url: nil, skip_further_checks?: true},
          service_error: %{code: :domain_not_found}
        )
    end
  end

  # Check A records of the the domains [domain, "www.#{domain}"]
  # at this point, domain can contain path
  @spec find_working_url(String.t()) :: {:ok, String.t()} | {:error, :domain_not_found}
  defp find_working_url(domain) do
    [domain_without_path | rest] = split_domain(domain)

    [
      domain_without_path,
      "www.#{domain_without_path}"
    ]
    |> Enum.reduce_while({:error, :domain_not_found}, fn d, _acc ->
      # For local testing, run the server with ALLOW_RESERVED_IPS=true
      case dns_lookup(d) do
        :ok -> {:halt, {:ok, "https://" <> unsplit_domain(d, rest)}}
        {:error, :resolve_host_error} -> {:cont, {:error, :domain_not_found}}
      end
    end)
  end

  @spec dns_lookup(String.t()) :: :ok | {:error, :resolve_host_error}
  defp dns_lookup(domain) do
    case Plausible.SSRF.resolve_host(domain) do
      {:ok, _ips} -> :ok
      {:error, _reason} -> {:error, :resolve_host_error}
    end
  end

  @spec split_domain(String.t()) :: [String.t()]
  defp split_domain(domain) do
    String.split(domain, "/", parts: 2)
  end

  @spec unsplit_domain(String.t(), [String.t()]) :: String.t()
  defp unsplit_domain(domain_without_path, rest) do
    Enum.join([domain_without_path] ++ rest, "/")
  end
end
