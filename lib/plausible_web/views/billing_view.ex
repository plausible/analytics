defmodule PlausibleWeb.BillingView do
  use PlausibleWeb, :view

  def present_date(date) do
    Date.from_iso8601!(date)
    |> Calendar.strftime("%-d %b %Y")
  end

  def present_currency("USD"), do: "$"
  def present_currency("EUR"), do: "€"
  def present_currency("GBP"), do: "£"
end
