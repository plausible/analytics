defmodule PlausibleWeb.BillingView do
  use PlausibleWeb, :view

  def present_date(date) do
    Date.from_iso8601!(date)
    |> Timex.format!("{D} {Mshort} {YYYY}")
  end

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
