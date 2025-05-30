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

  * `for_starter/1`
  * `for_growth/2`
  * `for_business/2`
  * `for_enterprise/1`.

  and renders them as HTML.

  The benefits in the given list can be either strings or functions
  returning a Phoenix component. This allows, for example, to render
  links within the plan benefit text.
  """
  def render(assigns) do
    ~H"""
    <ul role="list" class={["mt-8 space-y-1 text-sm leading-6", @class]}>
      <li :for={benefit <- @benefits} class="flex gap-x-1">
        <Heroicons.check class="shrink-0 h-5 w-5 text-indigo-600 dark:text-green-600" />
        {if is_binary(benefit), do: benefit, else: benefit.(assigns)}
      </li>
    </ul>
    """
  end

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
      "Everything in Starter",
      site_limit_benefit(growth_plan),
      team_member_limit_benefit(growth_plan)
    ]
    |> Kernel.++(feature_benefits(growth_plan))
    |> Kernel.--(starter_benefits)
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
        :shared_links -> ["Shared Links", "Embedded Dashboards"]
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
        class="text-indigo-500 hover:underline"
        href="https://plausible.io/white-label-web-analytics"
      >
        reselling
      </.link>
    </p>
    """
  end
end
