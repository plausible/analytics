defmodule Plausible.Site.RateLimiter do
  alias Plausible.Site
  alias Plausible.Site.Cache

  require Logger

  @policy_for_non_existing_sites :deny
  @policy_on_rate_limiting_backend_error :allow

  def policy(domain, opts \\ []) do
    case get_from_cache_or_refresh(domain, Keyword.get(opts, :cache_opts, [])) do
      %Ecto.NoResultsError{} ->
        @policy_for_non_existing_sites

      %Site{} = site ->
        check_rate_limit(site)

      {:error, _} ->
        @policy_on_rate_limiting_backend_error
    end
  end

  def check_rate_limit(%Site{ingest_rate_limit_threshold: nil}) do
    :allow
  end

  def check_rate_limit(%Site{ingest_rate_limit_threshold: threshold} = site)
      when is_integer(threshold) do
    case Hammer.check_rate("site:#{site.domain}", site.ingest_rate_limit_scale_seconds, threshold) do
      {:deny, _} ->
        :deny

      {:allow, _} ->
        :allow

      {:error, reason} ->
        Logger.error(
          "Error checking rate limit for '#{inspect(site.domain)}': #{inspect(reason)}"
        )

        @policy_on_rate_limiting_backend_error
    end
  end

  def get_from_cache_or_refresh(domain, cache_opts) do
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
