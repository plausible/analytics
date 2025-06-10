defmodule PlausibleWeb.Components.Billing.PlanBenefits do
  @moduledoc """
  This module exposes functions for rendering and returning plan
  benefits for Growth, Business, and Enterprise plans.
  """

  use Phoenix.Component

  attr :benefits, :list, required: true
  attr :class, :string, default: nil

  @doc """
  This function takes a list of benefits returned by either one of:

  * `Plausible.Billing.PlanBenefits.for_starter/1`
  * `Plausible.Billing.PlanBenefits.for_growth/2`
  * `Plausible.Billing.PlanBenefits.for_business/3`
  * `Plausible.Billing.PlanBenefits.for_enterprise/1`.

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
        <%= if benefit == "Sites API" do %>
          <.sites_api_benefit />
        <% else %>
          {benefit}
        <% end %>
      </li>
    </ul>
    """
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
