defmodule Plausible.Verification do
  @moduledoc """
  Module defining the user-agent used for site verification.
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
