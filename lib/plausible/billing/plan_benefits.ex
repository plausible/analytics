defmodule Plausible.Billing.PlanBenefits do
  @moduledoc false

  alias Plausible.Billing.Plan

  @shared_link_feature_labels ["Shared Links", "Embedded Dashboards"]

  @doc """
  This function takes a starter plan and returns a list representing
  the different benefits a user gets when subscribing to this plan.
  """
  def for_starter(starter_plan) do
    [
      site_limit_benefit(starter_plan),
      data_retention_benefit(starter_plan),
      "Intuitive, fast and privacy-friendly dashboard",
      "Email/Slack reports",
      "Google Analytics import"
    ]
    |> Kernel.++(feature_benefits(starter_plan))
    |> Kernel.++(["Saved Segments"])
  end

  @doc """
  Returns Growth benefits for the given Growth plan.

  A second argument is also required - list of Starter benefits. This
  is because we don't want to list the same benefits in both Starter
  and Growth. Everything in Starter is also included in Growth.
  """
  def for_growth(growth_plan, starter_benefits) do
    [
      if(Enum.empty?(starter_benefits), do: nil, else: "Everything in Starter"),
      site_limit_benefit(growth_plan),
      team_member_limit_benefit(growth_plan),
      if(Enum.empty?(starter_benefits), do: nil, else: "Team Management"),
      if(Enum.empty?(starter_benefits), do: nil, else: "Saved Segments")
    ]
    |> Kernel.++(feature_benefits(growth_plan))
    |> Kernel.--(starter_benefits)
    |> maybe_remove_new_starter_features(starter_benefits)
    |> Enum.filter(& &1)
  end

  @doc """
  Returns Business benefits for the given Business plan.

  A second argument is also required - list of Growth benefits. This
  is because we don't want to list the same benefits in both Growth
  and Business. Everything in Growth is also included in Business.
  """
  def for_business(plan, growth_benefits, starter_benefits) do
    [
      "Everything in Growth",
      site_limit_benefit(plan),
      team_member_limit_benefit(plan),
      data_retention_benefit(plan)
    ]
    |> Kernel.++(feature_benefits(plan))
    |> Kernel.--(growth_benefits)
    |> Kernel.--(starter_benefits)
    |> maybe_remove_new_starter_features(starter_benefits)
    |> Enum.filter(& &1)
  end

  @doc """
  This function only takes a list of business benefits. Since all
  limits and features of enterprise plans are configurable, we can
  say on the upgrade page that enterprise plans include everything
  in Business.
  """
  def for_enterprise(business_benefits) do
    team_members =
      cond do
        "Unlimited team members" in business_benefits -> nil
        "Up to 10 team members" in business_benefits -> "10+ team members"
        "Up to 50 team members" in business_benefits -> "50+ team members"
        # if there's nothing about team members in Business benefits, then
        # Growth has unlimited team members already. In that case, we don't
        # mention team members at all.
        true -> nil
      end

    sites =
      cond do
        "Up to 10 sites" in business_benefits -> "10+ sites"
        "Up to 50 sites" in business_benefits -> "50+ sites"
        # Before v4, every plan (both Growth and Business) had 50 sites.
        # Therefore, if Business benefits do not mention site limit, then
        # it's 50. Newer Business plans always define a higher site limit.
        true -> "50+ sites"
      end

    data_retention =
      if "5 years of data retention" in business_benefits, do: "5+ years of data retention"

    [
      "Everything in Business",
      sites,
      team_members,
      "600+ Stats API requests per hour",
      "Sites API",
      data_retention,
      "Technical onboarding",
      "Priority support"
    ]
    |> Enum.filter(& &1)
  end

  # In case Starter tier is not available for the team, starter_benefits
  # gets passed as `[]` into `for_growth/2` and `for_business/3`. However
  # even then we don't want the Growth or Business box to render any new
  # Starter features. That is to create balance between the number Growth,
  # Business and Enterprise benefits.
  defp maybe_remove_new_starter_features(benefits, starter_benefits) do
    if Enum.empty?(starter_benefits) do
      benefits -- @shared_link_feature_labels
    else
      benefits
    end
  end

  defp data_retention_benefit(%Plan{} = plan) do
    if plan.data_retention_in_years, do: "#{plan.data_retention_in_years} years of data retention"
  end

  defp team_member_limit_benefit(%Plan{} = plan) do
    case plan.team_member_limit do
      :unlimited -> "Unlimited team members"
      number -> "Up to #{number} team members"
    end
  end

  defp site_limit_benefit(%Plan{} = plan) do
    case plan.site_limit do
      1 -> "One site"
      site_limit -> "Up to #{site_limit} sites"
    end
  end

  defp feature_benefits(%Plan{} = plan) do
    Enum.flat_map(plan.features, fn feature_mod ->
      case feature_mod.name() do
        :goals -> ["Goals and custom events"]
        :stats_api -> ["Stats API (600 requests per hour)", "Looker Studio Connector"]
        :shared_links -> @shared_link_feature_labels
        :revenue_goals -> ["Ecommerce revenue attribution"]
        _ -> [feature_mod.display_name()]
      end
    end)
  end
end
