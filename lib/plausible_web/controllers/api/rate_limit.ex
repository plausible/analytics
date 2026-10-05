defmodule PlausibleWeb.Api.RateLimit do
  @moduledoc """
  Rate limits are imposed on API callers to prevent overloading the server.
  """

  use Plausible

  @default_hourly_request_limit_per_team on_ee(do: 600, else: 1_000_000)

  defp config(), do: Application.fetch_env!(:plausible, __MODULE__)

  def default_hourly_request_limit(), do: @default_hourly_request_limit_per_team

  def limit_key(team), do: "api_request:team:#{team.identifier}"

  def legacy_hourly_request_limit() do
    config()
    |> Keyword.fetch!(:legacy_per_user_hourly_request_limit)
  end

  def legacy_limit_key(user), do: "api_request:legacy_user:#{user.id}"

  def burst_request_limit(),
    do:
      config()
      |> Keyword.fetch!(:burst_request_limit)

  def burst_period_seconds(),
    do:
      config()
      |> Keyword.fetch!(:burst_period_seconds)

  @doc """
  Checks a request against both limits.

  The message in `{:error, :rate_limit, message}` is meant to be shown to the
  caller.
  """
  @spec check_rate_limit(String.t(), pos_integer()) :: :ok | {:error, :rate_limit, String.t()}
  def check_rate_limit(limit_key, hourly_limit) do
    with :ok <- check_hourly_limit(limit_key, hourly_limit) do
      check_burst_limit(limit_key)
    end
  end

  defp check_hourly_limit(limit_key, hourly_limit) do
    case Plausible.RateLimit.check_rate(limit_key, to_timeout(hour: 1), hourly_limit) do
      {:allow, _} ->
        :ok

      {:deny, _} ->
        {:error, :rate_limit,
         "Too many API requests. The limit is #{hourly_limit} per hour. Please contact us to request more capacity."}
    end
  end

  defp check_burst_limit(limit_key) do
    burst_period_seconds = burst_period_seconds()
    burst_request_limit = burst_request_limit()

    case Plausible.RateLimit.check_rate(
           limit_key,
           to_timeout(second: burst_period_seconds),
           burst_request_limit
         ) do
      {:allow, _} ->
        :ok

      {:deny, _} ->
        {:error, :rate_limit,
         "Too many API requests in a short period of time. The limit is #{burst_request_limit} per #{burst_period_seconds} seconds. Please throttle your requests."}
    end
  end
end
