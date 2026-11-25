defmodule PlausibleWeb.MCP.RateLimit do
  @moduledoc """
  Rate limits for MCP requests.

  Every authenticated MCP request spends the team's burst limit. Only
  `tools/call` spends the hourly limit, including calls that are refused
  later, like the Stats API. MCP requests and Stats API requests share
  one budget.
  """

  alias PlausibleWeb.Api.RateLimit, as: ApiRateLimit

  @spec check_tool_call(Plausible.Teams.Team.t()) ::
          :ok | {:error, :rate_limit_hourly | :rate_limit_burst, String.t()}
  def check_tool_call(team) do
    hourly_limit = Plausible.Teams.Billing.mcp_hourly_request_limit(team)

    case ApiRateLimit.check_burst_and_hourly(ApiRateLimit.limit_key(team), hourly_limit) do
      :ok -> :ok
      {:error, reason} -> {:error, reason, message(reason, hourly_limit)}
    end
  end

  @spec check_burst(Plausible.Teams.Team.t()) :: :ok | {:error, :rate_limit_burst}
  def check_burst(team), do: ApiRateLimit.check_burst(ApiRateLimit.limit_key(team))

  defp message(:rate_limit_hourly, hourly_limit) do
    "Your team reached its hourly request limit (#{hourly_limit} per hour). " <>
      "The limit resets in #{minutes_to_next_full_hour()}."
  end

  defp message(:rate_limit_burst, _hourly_limit) do
    "Too many requests in a short time. The limit is #{ApiRateLimit.burst_request_limit()} " <>
      "per #{ApiRateLimit.burst_period_seconds()} seconds. Try again in a few seconds."
  end

  defp minutes_to_next_full_hour() do
    case 60 - DateTime.utc_now().minute do
      1 -> "1 minute"
      minutes -> "#{minutes} minutes"
    end
  end
end
