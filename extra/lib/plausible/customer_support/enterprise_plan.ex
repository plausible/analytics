defmodule Plausible.CustomerSupport.EnterprisePlan do
  @moduledoc """
  Custom plan price estimation
  """
  @spec estimate(
          String.t(),
          pos_integer(),
          pos_integer(),
          pos_integer(),
          pos_integer(),
          list(String.t())
        ) :: Decimal.t()
  def estimate(
        billing_interval,
        pageviews_per_month,
        sites_limit,
        team_members_limit,
        api_calls_limit,
        features
      ) do
    pv_rate =
      pv_rate(pageviews_per_month)

    sites_rate =
      sites_rate(sites_limit)

    team_member_unit_rate = team_member_unit_rate(features)

    team_members_rate =
      team_members_rate(team_members_limit, team_member_unit_rate)

    api_calls_rate =
      api_calls_rate(api_calls_limit)

    features_rate =
      features_rate(features)

    cost_per_month =
      Decimal.from_float(
        (pv_rate +
           sites_rate +
           team_members_rate +
           api_calls_rate +
           features_rate) * 1.0
      )
      |> Decimal.round(2)

    if billing_interval == "monthly" do
      cost_per_month
    else
      cost_per_month |> Decimal.mult(10) |> Decimal.round(2)
    end
  end

  def pv_rate(pvs) when pvs <= 10_000, do: 19
  def pv_rate(pvs) when pvs <= 100_000, do: 39
  def pv_rate(pvs) when pvs <= 200_000, do: 59
  def pv_rate(pvs) when pvs <= 500_000, do: 99
  def pv_rate(pvs) when pvs <= 1_000_000, do: 139
  def pv_rate(pvs) when pvs <= 2_000_000, do: 179
  def pv_rate(pvs) when pvs <= 5_000_000, do: 259
  def pv_rate(pvs) when pvs <= 10_000_000, do: 339
  def pv_rate(pvs) when pvs <= 20_000_000, do: 639
  def pv_rate(pvs) when pvs <= 50_000_000, do: 1379
  def pv_rate(pvs) when pvs <= 100_000_000, do: 2059
  def pv_rate(pvs) when pvs <= 200_000_000, do: 3259
  def pv_rate(pvs) when pvs <= 300_000_000, do: 4739
  def pv_rate(pvs) when pvs <= 400_000_000, do: 5979
  def pv_rate(pvs) when pvs <= 500_000_000, do: 7459
  def pv_rate(pvs) when pvs <= 1_000_000_000, do: 14_439
  def pv_rate(_), do: 14_439

  def sites_rate(n) when n <= 50, do: 0
  def sites_rate(n), do: n * 0.1

  def team_member_unit_rate(f) do
    if "sso" in f, do: 15, else: 5
  end

  def team_members_rate(n, rate_per_member) when n > 10, do: (n - 10) * rate_per_member
  def team_members_rate(_, _), do: 0

  def api_calls_rate(n) when n <= 600, do: 0
  def api_calls_rate(n) when n > 600, do: round(n / 1_000) * 100

  @feature_rates %{
    "sites_api" => 99,
    "sso" => 299
  }

  def features_rate(features) do
    features
    |> Enum.map(&Map.get(@feature_rates, &1, 0))
    |> Enum.sum()
  end
end
