defmodule Plausible.InstallationSupport.BrowserlessConfig do
  @moduledoc """
  Req options for browserless.io requests
  """
  use Plausible

  @retry_policy_by_status %{
    # rate limit
    429 => {:delay, 1000},
    # timeout
    408 => {:delay, 500},
    # even 400 are verified manually to sometimes succeed on retry
    400 => {:delay, 500}
  }

  @doc """
  Examples:

    iex> retry_browserless_request([429, 400]).(nil, %{status: 429})
    {:delay, 1000}

    iex> retry_browserless_request([429, 400]).(nil, %{status: 400})
    {:delay, 500}

    iex> retry_browserless_request([429, 400]).(nil, %{status: 408})
    nil

    iex> retry_browserless_request([429, 400]).(nil, :some_error)
    false
  """

  def retry_browserless_request(statuses_to_retry) do
    policies = Map.take(@retry_policy_by_status, statuses_to_retry)

    fn _request, response_or_error ->
      case response_or_error do
        %{status: status} -> Map.get(policies, status)
        _ -> false
      end
    end
  end

  on_ee do
    def browserless_function_api_endpoint() do
      config = Application.fetch_env!(:plausible, __MODULE__)
      token = Keyword.fetch!(config, :token)
      endpoint = Keyword.fetch!(config, :endpoint)
      Path.join(endpoint, "function?token=#{token}&stealth")
    end
  else
    def browserless_function_api_endpoint() do
      "Browserless API should not be called on Community Edition"
    end
  end
end
