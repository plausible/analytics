defmodule Plausible.CustomerSupport.TrialProspects do
  @moduledoc """
  Pure scoring logic for ranking trial teams by revenue potential. Turns a
  team's partial traffic sample and premium-feature usage into an estimated MRR.
  """

  # Static reference pricing (EUR/mo) + pageview ladder. Hand-maintained; keep in sync when public pricing changes.
  @pricing_path Application.app_dir(:plausible, ["priv", "trial_prospect_pricing.json"])
  @external_resource @pricing_path
  @tiers @pricing_path
         |> File.read!()
         |> Jason.decode!()
         |> Map.fetch!("tiers")
         |> Enum.map(fn tier ->
           %{
             limit: tier["monthly_pageview_limit"],
             starter: tier["starter"],
             growth: tier["growth"],
             business: tier["business"]
           }
         end)
         |> Enum.sort_by(& &1.limit)
  @ladder Enum.map(@tiers, & &1.limit)

  @business_features [
    :props,
    :funnels,
    :revenue_goals,
    :stats_api
  ]
  @growth_features [:shared_links, :site_segments, :site_annotations]

  @starter_site_limit 1
  @growth_site_limit 3
  @starter_member_limit 0
  @growth_member_limit 3

  @kind_rank %{starter: 0, growth: 1, business: 2}

  @doc """
  Combines feature usage, site/member counts + a monthly estimate into the
  persisted scoring fields: `kind`, `forced_by`, `pageview_limit`,
  `over_top_tier`, `estimated_mrr`.
  """
  @spec score(non_neg_integer(), [module()], non_neg_integer(), non_neg_integer()) :: %{
          kind: :starter | :growth | :business,
          forced_by: [String.t()],
          pageview_limit: pos_integer() | nil,
          over_top_tier: boolean(),
          estimated_mrr: non_neg_integer() | nil
        }
  def score(estimated_monthly, feature_modules, site_count, member_count) do
    {kind, forced_by} = plan_kind(feature_modules, site_count, member_count)
    {limit, over_top_tier} = pageview_rung(estimated_monthly)

    %{
      kind: kind,
      forced_by: forced_by,
      pageview_limit: limit,
      over_top_tier: over_top_tier,
      estimated_mrr: estimated_mrr(kind, limit, over_top_tier)
    }
  end

  @spec plan_kind([module()], non_neg_integer(), non_neg_integer()) ::
          {:starter | :growth | :business, [String.t()]}
  defp plan_kind(feature_modules, site_count, member_count) do
    used = Enum.map(feature_modules, & &1.name())

    feature_k = feature_kind(used)
    site_k = site_count_kind(site_count)
    member_k = member_count_kind(member_count)

    kind = feature_k |> higher_kind(site_k) |> higher_kind(member_k)

    {kind, forced_by(used, kind, site_k, member_k)}
  end

  @spec pageview_rung(non_neg_integer()) :: {pos_integer() | nil, boolean()}
  defp pageview_rung(estimated_monthly) do
    case Enum.find(@ladder, &(&1 >= estimated_monthly)) do
      nil -> {nil, true}
      limit -> {limit, false}
    end
  end

  @spec estimated_mrr(:starter | :growth | :business, pos_integer() | nil, boolean()) ::
          non_neg_integer() | nil
  defp estimated_mrr(_kind, _limit, true), do: nil

  defp estimated_mrr(kind, limit, false) do
    tier = Enum.find(@tiers, &(&1.limit == limit))
    tier && Map.fetch!(tier, kind)
  end

  defp feature_kind(used) do
    cond do
      forcing(used, @business_features) != [] -> :business
      forcing(used, @growth_features) != [] -> :growth
      true -> :starter
    end
  end

  defp site_count_kind(n) when n <= @starter_site_limit, do: :starter
  defp site_count_kind(n) when n <= @growth_site_limit, do: :growth
  defp site_count_kind(_), do: :business

  defp member_count_kind(n) when n <= @starter_member_limit, do: :starter
  defp member_count_kind(n) when n <= @growth_member_limit, do: :growth
  defp member_count_kind(_), do: :business

  defp higher_kind(a, b), do: if(@kind_rank[a] >= @kind_rank[b], do: a, else: b)

  defp forced_by(_used, :starter, _site_k, _member_k), do: []

  defp forced_by(used, kind, site_k, member_k) do
    forcing_for(used, kind) ++
      List.wrap(if(site_k == kind, do: "site_limit")) ++
      List.wrap(if(member_k == kind, do: "team_member_limit"))
  end

  defp forcing_for(used, :business), do: forcing(used, @business_features)
  defp forcing_for(used, :growth), do: forcing(used, @growth_features)

  defp forcing(used, tier_features) do
    used
    |> Enum.filter(&(&1 in tier_features))
    |> Enum.map(&Atom.to_string/1)
    |> Enum.sort()
  end
end
