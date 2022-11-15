defmodule Plausible.Site.RateLimiter do
  alias Plausible.Site
  alias Plausible.Site.Cache

  require Logger

  @policy_for_non_existing_sites :deny
  @policy_on_rate_limiting_backend_error :allow

  @spec allow?(String.t(), Keyword.t()) :: boolean()
  def allow?(domain, opts) do
    policy(domain, opts) == :allow
  end

  @spec policy(String.t(), Keyword.t()) :: :allow | :deny
  def policy(domain, opts \\ []) do
    case get_from_cache_or_refresh(domain, Keyword.get(opts, :cache_opts, [])) do
      %Ecto.NoResultsError{} ->
        @policy_for_non_existing_sites

      %Site{} = site ->
        check_rate_limit(site, opts)

      {:error, _} ->
        @policy_on_rate_limiting_backend_error
    end
  end

  @spec key(String.t()) :: String.t()
  def key(domain) do
    "ingest:site:#{domain}"
  end

  defp check_rate_limit(%Site{ingest_rate_limit_threshold: nil}, _opts) do
    :allow
  end

  defp check_rate_limit(%Site{ingest_rate_limit_threshold: threshold} = site, opts)
       when is_integer(threshold) do
    key = Keyword.get(opts, :key, key(site.domain))
    scale_ms = site.ingest_rate_limit_scale_seconds * 1_000

    case Hammer.check_rate(key, scale_ms, threshold) do
      {:deny, _} ->
        :deny

      {:allow, _} ->
        :allow

      {:error, reason} ->
        Logger.error(
          "Error checking rate limit for '#{key}': #{inspect(reason)}. Falling back to: #{@policy_on_rate_limiting_backend_error}"
        )

        @policy_on_rate_limiting_backend_error
    end
  end

  defp get_from_cache_or_refresh(domain, cache_opts) do
    case Cache.get(domain, cache_opts) do
      %Site{} = site ->
        site

      %Ecto.NoResultsError{} = not_found ->
        not_found

      nil ->
        with {:ok, refreshed_item} <- Cache.refresh_one(domain, cache_opts) do
          refreshed_item
        end
    end
  end
end
