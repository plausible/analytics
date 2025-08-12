defmodule Plausible.InstallationSupport.Checks.Url do
  @moduledoc """
  Checks if site domain has an A record.
  If not, checks if prepending `www.` helps,
  because we have specifically requested customers to register the domain with `www.` prefix.
  If not, skips all further checks.
  """

  use Plausible.InstallationSupport.Check

  @impl true
  def report_progress_as, do: "We're trying to reach your website"

  @impl true
  @spec perform(Plausible.InstallationSupport.State.t()) ::
          Plausible.InstallationSupport.State.t()
  def perform(%State{url: url} = state) when is_binary(url) do
    with {:ok, %URI{scheme: scheme} = uri} when scheme in ["https"] <- URI.new(url),
         :ok <- check_domain(uri.host) do
      stripped_url = URI.to_string(%URI{uri | query: nil, fragment: nil})
      %State{state | url: stripped_url}
    else
      {:error, :no_a_record} ->
        put_diagnostics(%State{state | skip_further_checks?: true},
          service_error: :domain_not_found
        )

      _ ->
        put_diagnostics(%State{state | skip_further_checks?: true},
          service_error: :invalid_url
        )
    end
  end

  def perform(%State{data_domain: domain} = state) when is_binary(domain) do
    case find_working_url(domain) do
      {:ok, working_url} ->
        %State{state | url: working_url}

      {:error, :domain_not_found} ->
        put_diagnostics(%State{state | url: nil, skip_further_checks?: true},
          service_error: :domain_not_found
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
      case check_domain(d) do
        :ok -> {:halt, {:ok, "https://" <> unsplit_domain(d, rest)}}
        {:error, :no_a_record} -> {:cont, {:error, :domain_not_found}}
      end
    end)
  end

  @spec check_domain(String.t()) :: :ok | {:error, :no_a_record}
  defp check_domain(domain) do
    lookup_timeout = 1_000
    resolve_timeout = 1_000

    case :inet_res.lookup(
           to_charlist(domain),
           :in,
           :a,
           [timeout: resolve_timeout],
           lookup_timeout
         ) do
      [{a, b, c, d} | _]
      when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) ->
        :ok

      # this may mean timeout or no DNS record
      [] ->
        {:error, :no_a_record}
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
