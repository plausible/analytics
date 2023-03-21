defmodule Plausible.Site.GateKeeper do
  @type policy() :: :allow | :not_found | :block | :throttle
  @policy_for_non_existing_sites :not_found
  @policy_on_rate_limiting_backend_error :allow

  @type t() :: :allow | {:deny, policy()}

  @moduledoc """
  Thin wrapper around Hammer for gate keeping domain-specific events
  during the ingestion phase. When the site is allowed, gate keeping
  check returns `:allow`, otherwise a `:deny` tagged tuple is returned
  with one of the following policy markers:
    * `:not_found` (indicates site not found in cache)
    * `:block` (indicates disabled sites)
    * `:throttle` (indicates rate limiting)

  Rate Limiting buckets are configured per site (externally via the CRM).
  See: `Plausible.Site`

  To look up each site's configuration, the RateLimiter fetches
  a Site by domain using `Plausible.Cache` interface.

  The module defines two policies outside the regular bucket inspection:
    * when the the site is not found in cache: #{@policy_for_non_existing_sites}
    * when the underlying rate limiting mechanism returns
      an internal error: #{@policy_on_rate_limiting_backend_error}
  """
  alias Plausible.Site
  alias Plausible.Site.Cache

  require Logger

  @spec check(String.t(), Keyword.t()) :: t()
  def check(domain, opts \\ []) when is_binary(domain) do
    case policy(domain, opts) do
      :allow -> :allow
      other -> {:deny, other}
    end
  end

  @spec key(String.t()) :: String.t()
  def key(domain) do
    "ingest:site:#{domain}"
  end

  defp policy(domain, opts) when is_binary(domain) do
    result =
      case Cache.get(domain, Keyword.get(opts, :cache_opts, [])) do
        nil ->
          @policy_for_non_existing_sites

        %Site{} = site ->
          check_rate_limit(site, opts)
      end

    result
  end

  defp check_rate_limit(%Site{ingest_rate_limit_threshold: nil}, _opts) do
    :allow
  end

  defp check_rate_limit(%Site{ingest_rate_limit_threshold: 0}, _opts) do
    :block
  end

  defp check_rate_limit(%Site{ingest_rate_limit_threshold: threshold} = site, opts)
       when is_integer(threshold) do
    key = Keyword.get(opts, :key, key(site.domain))
    scale_ms = site.ingest_rate_limit_scale_seconds * 1_000

    case Hammer.check_rate(key, scale_ms, threshold) do
      {:deny, _} ->
        :throttle

      {:allow, _} ->
        :allow

      {:error, reason} ->
        Logger.error(
          "Error checking rate limit for '#{key}': #{inspect(reason)}. Falling back to: #{@policy_on_rate_limiting_backend_error}"
        )

        @policy_on_rate_limiting_backend_error
    end
  end
end
