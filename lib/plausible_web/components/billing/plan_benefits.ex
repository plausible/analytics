defmodule PlausibleWeb.Components.Billing.PlanBenefits do
  @moduledoc """
  This module exposes functions for rendering and returning plan
  benefits for Growth, Business, and Enterprise plans.
  """

  use Phoenix.Component
  alias Plausible.Billing.Plan

  attr :benefits, :list, required: true
  attr :class, :string, default: nil

  @doc """
  This function takes a list of benefits returned by either one of:

  * `for_growth/1`
  * `for_business/2`
  * `for_enterprise/1`.

  and renders them as HTML.

  The benefits in the given list can be either strings or functions
  returning a Phoenix component. This allows, for example, to render
  links within the plan benefit text.
  """
  def render(assigns) do
    ~H"""
    <ul role="list" class={["mt-8 space-y-3 text-sm leading-6 xl:mt-10", @class]}>
      <li :for={benefit <- @benefits} class="flex gap-x-3">
        <Heroicons.check class="h-6 w-5 text-indigo-600 dark:text-green-600" />
        {if is_binary(benefit), do: benefit, else: benefit.(assigns)}
      </li>
    </ul>
    """
  end

  @doc """
  This function takes a growth plan and returns a list representing
  the different benefits a user gets when subscribing to this plan.
  """
  def for_growth(plan) do
    [
      team_member_limit_benefit(plan),
      site_limit_benefit(plan),
      data_retention_benefit(plan),
      "Intuitive, fast and privacy-friendly dashboard",
      "Email/Slack reports",
      "Google Analytics import"
    ]
    |> Kernel.++(feature_benefits(plan))
    |> Kernel.++(["Saved Segments"])
    |> Enum.filter(& &1)
  end

  @doc """
  Returns Business benefits for the given Business plan.

  A second argument is also required - list of Growth benefits. This
  is because we don't want to list the same benefits in both Growth
  and Business. Everything in Growth is also included in Business.
  """
  def for_business(plan, growth_benefits) do
    [
      "Everything in Growth",
      team_member_limit_benefit(plan),
      site_limit_benefit(plan),
      data_retention_benefit(plan)
    ]
    |> Kernel.++(feature_benefits(plan))
    |> Kernel.--(growth_benefits)
    |> Kernel.++(["Priority support"])
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
      if "Up to 10 team members" in business_benefits, do: "10+ team members"

    data_retention =
      if "5 years of data retention" in business_benefits, do: "5+ years of data retention"

    [
      "Everything in Business",
      team_members,
      "50+ sites",
      "600+ Stats API requests per hour",
      &sites_api_benefit/1,
      data_retention,
      "Technical onboarding"
    ]
    |> Enum.filter(& &1)
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

  defp site_limit_benefit(%Plan{} = plan), do: "Up to #{plan.site_limit} sites"

  defp feature_benefits(%Plan{} = plan) do
    Enum.flat_map(plan.features, fn feature_mod ->
      case feature_mod.name() do
        :goals -> ["Goals and custom events"]
        :teams -> []
        :shared_links -> []
        :stats_api -> ["Stats API (600 requests per hour)", "Looker Studio Connector"]
        :revenue_goals -> ["Ecommerce revenue attribution"]
        _ -> [feature_mod.display_name()]
      end
    end)
  end

  defp sites_api_benefit(assigns) do
    ~H"""
    <p>
      Sites API access for
      <.link
        class="text-indigo-500 hover:text-indigo-400"
        href="https://plausible.io/white-label-web-analytics"
      >
        reselling
      </.link>
    </p>
    """
  end
end
