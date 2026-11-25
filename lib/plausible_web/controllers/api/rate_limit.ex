defmodule PlausibleWeb.Api.RateLimit do
  @moduledoc """
  Rate limits are imposed on API callers to prevent overloading the server.
  """

  defp config(), do: Application.fetch_env!(:plausible, __MODULE__)

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
  Checks a request against the given hourly limit, and a fixed burst limit.
  """
  @spec check_burst_and_hourly(String.t(), pos_integer()) ::
          :ok | {:error, :rate_limit_hourly | :rate_limit_burst}
  def check_burst_and_hourly(limit_key, hourly_limit) do
    with :ok <- check_hourly(limit_key, hourly_limit) do
      check_burst(limit_key)
    end
  end

  defp check_hourly(limit_key, hourly_limit) do
    case Plausible.RateLimit.check_rate(limit_key, to_timeout(hour: 1), hourly_limit) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limit_hourly}
    end
  end

  @doc """
  Checks a request against the fixed burst limit.
  """
  @spec check_burst(String.t()) :: :ok | {:error, :rate_limit_burst}
  def check_burst(limit_key) do
    case Plausible.RateLimit.check_rate(
           limit_key,
           to_timeout(second: burst_period_seconds()),
           burst_request_limit()
         ) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limit_burst}
    end
  end
end
