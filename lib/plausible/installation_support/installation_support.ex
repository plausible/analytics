defmodule Plausible.InstallationSupport do
  @moduledoc """
  This top level module is the middle ground between pre-installation
  site scans and verification of whether Plausible has been installed
  correctly.

  Defines the user-agent used by Elixir-native HTTP requests as well
  as headless browser checks on the client side via Browserless.
  """
  use Plausible

  on_ee do
    def user_agent() do
      "Plausible Verification Agent - if abused, contact support@plausible.io"
    end

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

    def user_agent() do
      "Plausible Community Edition"
    end
  end
end
