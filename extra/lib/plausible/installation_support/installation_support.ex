defmodule Plausible.InstallationSupport do
  @moduledoc """
  This top level module is the middle ground between pre-installation
  site scans and verification of whether Plausible has been installed
  correctly.

  Defines the user-agent used with checks.
  """
  use Plausible

  on_ee do
    def user_agent() do
      "Plausible Verification Agent - if abused, contact support@plausible.io"
    end
  else
    def user_agent() do
      "Plausible Community Edition"
    end
  end
end
