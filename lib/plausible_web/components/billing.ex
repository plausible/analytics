defmodule PlausibleWeb.Components.Billing do
  @moduledoc false

  use Phoenix.Component
  import PlausibleWeb.Components.Generic
  alias PlausibleWeb.Router.Helpers, as: Routes

  slot(:inner_block, required: true)
  attr(:rest, :global)

  def usage_and_limits_table(assigns) do
    ~H"""
    <table class="min-w-full text-gray-900 dark:text-gray-100" {@rest}>
      <tbody class="divide-y divide-gray-200 dark:divide-gray-600">
        <%= render_slot(@inner_block) %>
      </tbody>
    </table>
    """
  end

  attr(:title, :string, required: true)
  attr(:usage, :any, required: true)
  attr(:limit, :integer, default: nil)
  attr(:pad, :boolean, default: false)
  attr(:rest, :global)

  def usage_and_limits_row(assigns) do
    ~H"""
    <tr {@rest}>
      <td class={["py-4 text-sm whitespace-nowrap text-left", @pad && "pl-6"]}><%= @title %></td>
      <td class="py-4 text-sm whitespace-nowrap text-right">
        <%= render_quota(@usage) %>
        <%= if @limit, do: "/ #{render_quota(@limit)}" %>
      </td>
    </tr>
    """
  end

  defp render_quota(quota) do
    case quota do
      quota when is_number(quota) -> Cldr.Number.to_string!(quota)
      :unlimited -> "∞"
      nil -> ""
    end
  end

  def monthly_quota_box(%{business_tier: true} = assigns) do
    ~H"""
    <div
      class="h-32 px-2 py-4 my-4 text-center bg-gray-100 rounded dark:bg-gray-900"
      style="width: 11.75rem;"
    >
      <h4 class="font-black dark:text-gray-100">Monthly quota</h4>
      <div class="py-2 text-xl font-medium dark:text-gray-100">
        <%= PlausibleWeb.AuthView.subscription_quota(@subscription, format: :long) %>
      </div>
      <%= if @subscription && @subscription.status == "past_due" do %>
        <span
          class="text-sm text-gray-600 dark:text-gray-400 font-medium"
          tooltip="Please update your billing details before changing plans"
        >
          Change plan
        </span>
      <% else %>
        <.styled_link
          href={Routes.billing_path(@conn, :choose_plan)}
          class="text-sm font-medium"
        >
          <%= upgrade_link_text(@subscription) %>
        </.styled_link>
      <% end %>
    </div>
    """
  end

  def monthly_quota_box(%{business_tier: false} = assigns) do
    ~H"""
    <div
      class="h-32 px-2 py-4 my-4 text-center bg-gray-100 rounded dark:bg-gray-900"
      style="width: 11.75rem;"
    >
      <h4 class="font-black dark:text-gray-100">Monthly quota</h4>
      <%= if @subscription do %>
        <div class="py-2 text-xl font-medium dark:text-gray-100">
          <%= PlausibleWeb.AuthView.subscription_quota(@subscription) %> pageviews
        </div>

        <.styled_link
          :if={@subscription.status == "active"}
          href={Routes.billing_path(@conn, :change_plan_form)}
          class="text-sm font-medium"
        >
          Change plan
        </.styled_link>

        <span
          :if={@subscription.status == "past_due"}
          class="text-sm text-gray-600 dark:text-gray-400 font-medium"
          tooltip="Please update your billing details before changing plans"
        >
          Change plan
        </span>
      <% else %>
        <div class="py-2 text-xl font-medium dark:text-gray-100">Free trial</div>
        <.styled_link class="text-sm font-medium" href={Routes.billing_path(@conn, :upgrade)}>
          Upgrade
        </.styled_link>
      <% end %>
    </div>
    """
  end

  defp upgrade_link_text(nil), do: "Upgrade"
  defp upgrade_link_text(_subscription), do: "Change plan"
end
