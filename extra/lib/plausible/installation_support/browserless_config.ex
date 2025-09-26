defmodule Plausible.InstallationSupport.BrowserlessConfig do
  @moduledoc """
  Req options for browserless.io requests
  """
  use Plausible

  def retry_browserless_request(_request, %{status: status}) do
    case status do
      # rate limit
      429 -> {:delay, 1000}
      # timeout
      408 -> {:delay, 500}
      # other errors
      _ -> false
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
