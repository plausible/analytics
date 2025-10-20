defmodule Plausible.InstallationSupport.BrowserlessConfig do
  @moduledoc """
  Req options for browserless.io requests
  """
  use Plausible

  @retry_policy %{
    # rate limit
    429 => {:delay, 1000},
    # even 400 are verified manually to sometimes succeed on retry
    400 => {:delay, 500}
  }

  def retry_policy(), do: @retry_policy

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
