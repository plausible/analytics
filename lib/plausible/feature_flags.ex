defmodule Plausible.FeatureFlags do
  @moduledoc """
  This module lists available feature flags
  """

  def get_flags(user, site),
    do:
      [:channels, :saved_segments, :scroll_depth]
      |> Enum.into(
        %{},
        fn flag ->
          {flag, FunWithFlags.enabled?(flag, for: user) || FunWithFlags.enabled?(flag, for: site)}
        end
      )
end
