defmodule PlausibleWeb.EmailView do
  use PlausibleWeb, :view

  def admin_email do
    Application.get_env(:plausible, :admin_email)
  end

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def base_domain() do
    PlausibleWeb.Endpoint.host()
  end

  def user_salutation(user) do
    if user.name do
      String.split(user.name) |> List.first()
    else
      ""
    end
  end

  def suggested_plan_name(usage) do
    cond do
      usage <= 9_000 ->
        "10k/mo"

      usage <= 90_000 ->
        "100k/mo"

      usage <= 180_000 ->
        "200k/mo"

      usage <= 450_000 ->
        "500k/mo"

      usage <= 900_000 ->
        "1m/mo"

      usage <= 1_800_000 ->
        "2m/mo"

      usage <= 4_500_000 ->
        "5m/mo"

      true ->
        throw("Huge account")
    end
  end

  def suggested_plan_cost(usage) do
    cond do
      usage <= 9_000 ->
        "$6/mo"

      usage <= 90_000 ->
        "$12/mo"

      usage <= 180_000 ->
        "$18/mo"

      usage <= 450_000 ->
        "$27/mo"

      usage <= 900_000 ->
        "$48/mo"

      usage <= 1_800_000 ->
        "$69/mo"

      usage <= 4_500_000 ->
        "$99/mo"

      true ->
        throw("Huge account")
    end
  end
end
