defmodule Plausible.License do
  @moduledoc """
    This module ensures that you cannot utilize the Plausible Analytics Enterprise Edition without a valid license key.
    The modules contained within the ee/ and assets/js/dashboard/ee directories are Copyright © Plausible Insights OÜ.
    We have made this code available solely for informational and transparency purposes. No rights are granted to use,
    distribute, or exploit this software in any form.

    Any attempt to disable or modify the behavior of this module will be considered a violation of copyright.
    If you wish to use the Plausible Analytics Enterprise Edition for your own requirements, please contact us
    at hello@plausible.io to discuss obtaining a license.
  """

  require Logger

  def ensure_valid_license do
    if not has_valid_license?() do
      Logger.error(
        "Invalid or no license key provided for Plausible Analytics Enterprise Edition. Please contact hello@plausible.io to acquire a license."
      )

      Logger.error("Shutting down")
      System.stop()
    end
  end

  @license_hash "2zbwo5z6taa5vqk6meecksezixdpo6up"
  defp has_valid_license?() do
    hash =
      :crypto.hash(:sha, Application.fetch_env!(:plausible, :license_key))
      |> Base.encode32(case: :lower)

    hash == @license_hash
  end
end
