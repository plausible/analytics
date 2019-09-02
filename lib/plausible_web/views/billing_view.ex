defmodule PlausibleWeb.BillingView do
  use PlausibleWeb, :view

  def reccommended_plan(usage) do
    cond do
      usage < 9000 ->
        "10k / mo"
      usage < 90_000 ->
        "100k / mo"
      usage < 900_000 ->
        "1m / mo"
      true ->
        "custom"
    end
  end
end
