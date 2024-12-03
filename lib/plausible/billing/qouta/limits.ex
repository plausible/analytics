defmodule Plausible.Billing.Quota.Limits do
  @moduledoc false

  @pageview_allowance_margin 0.1

  def pageview_limit_with_margin(limit, margin \\ nil) do
    margin = if margin, do: margin, else: @pageview_allowance_margin
    ceil(limit * (1 + margin))
  end
end
