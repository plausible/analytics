defmodule Plausible.CustomerSupport.EnterprisePlan do
  @moduledoc """
  Custom plan price estimation
  """
  @spec estimate(
          :business | :growth,
          String.t(),
          pos_integer(),
          pos_integer(),
          pos_integer(),
          pos_integer(),
          list(String.t())
        ) :: Decimal.t()
  def estimate(
        kind,
        billing_interval,
        pageviews_per_month,
        sites_limit,
        team_members_limit,
        api_calls_limit,
        features
      ) do
    cost_per_month =
      Decimal.from_float(
        pv_rate(kind, pageviews_per_month) + sites_rate(sites_limit) +
          team_members_rate(team_members_limit) + api_calls_rate(api_calls_limit) +
          features_rate(features)
      )
      |> Decimal.round(2)

    if billing_interval == "monthly" do
      cost_per_month
    else
      cost_per_month |> Decimal.mult(10) |> Decimal.round(2)
    end
  end

  def pv_rate(:growth, pvs) when pvs <= 20_000_000, do: 319
  def pv_rate(:growth, pvs) when pvs <= 50_000_000, do: 689
  def pv_rate(:growth, pvs) when pvs <= 100_000_000, do: 1029
  def pv_rate(:growth, pvs) when pvs <= 200_000_000, do: 1629
  def pv_rate(:growth, pvs) when pvs <= 300_000_000, do: 2369
  def pv_rate(:growth, pvs) when pvs <= 400_000_000, do: 2989
  def pv_rate(:growth, pvs) when pvs <= 500_000_000, do: 3729
  def pv_rate(:growth, pvs) when pvs <= 1_000_000_000, do: 7219
  def pv_rate(:growth, _), do: 7219

  def pv_rate(:business, pvs) when pvs <= 20_000_000, do: 639
  def pv_rate(:business, pvs) when pvs <= 50_000_000, do: 1379
  def pv_rate(:business, pvs) when pvs <= 100_000_000, do: 2059
  def pv_rate(:business, pvs) when pvs <= 200_000_000, do: 3259
  def pv_rate(:business, pvs) when pvs <= 300_000_000, do: 4739
  def pv_rate(:business, pvs) when pvs <= 400_000_000, do: 5979
  def pv_rate(:business, pvs) when pvs <= 500_000_000, do: 7459
  def pv_rate(:business, pvs) when pvs <= 1_000_000_000, do: 14_439
  def pv_rate(:business, _), do: 14_439

  def sites_rate(n), do: n * 0.1

  def team_members_rate(n), do: n * 5

  def api_calls_rate(n) when n <= 1_000, do: 100
  def api_calls_rate(n) when n <= 2_000, do: 200
  def api_calls_rate(_), do: 300

  def features_rate(f) do
    if "sites_api" in f, do: 99, else: 0
  end
end
