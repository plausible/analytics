defmodule Plausible.Verification do
  @moduledoc """
  Module defining the user-agent used for site verification.
  """
  use Plausible

  @feature_flag :verification

  def enabled?(user) do
    enabled_via_config? =
      :plausible |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(:enabled?)

    enabled_for_user? = not is_nil(user) and FunWithFlags.enabled?(@feature_flag, for: user)
    enabled_via_config? or enabled_for_user?
  end

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
