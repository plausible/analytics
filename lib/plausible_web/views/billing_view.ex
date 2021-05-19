defmodule PlausibleWeb.BillingView do
  use PlausibleWeb, :view

  def admin_email do
    Application.get_env(:plausible, :admin_email)
  end

  def base_domain do
    PlausibleWeb.Endpoint.host()
  end

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def present_date(date) do
    Date.from_iso8601!(date)
    |> Timex.format!("{D} {Mshort} {YYYY}")
  end

  def present_currency("USD"), do: "$"
  def present_currency("EUR"), do: "€"
  def present_currency("GBP"), do: "£"

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
