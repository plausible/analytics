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

    def verification_checks_mod do
      if Mix.env() in [:dev, :e2e_test] do
        Plausible.InstallationSupport.Verification.ChecksMock
      else
        Plausible.InstallationSupport.Verification.Checks
      end
    end
  else
    def user_agent() do
      "Plausible Community Edition"
    end
  end
end
