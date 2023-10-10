defmodule PlausibleWeb.Components.Billing do
  @moduledoc false

  use Phoenix.Component
  import PlausibleWeb.Components.Generic
  alias PlausibleWeb.Router.Helpers, as: Routes
  alias Plausible.Billing.Subscription

  attr(:site, Plausible.Site, required: true)
  attr(:current_user, Plausible.Auth.User, required: true)
  attr(:feature_mod, :atom, required: true, values: Plausible.Billing.Feature.list())
  attr(:grandfathered?, :boolean, default: false)
  attr(:size, :atom, default: :sm)
  attr(:rest, :global)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def extra_feature_notice(assigns) do
    private_preview? = not FunWithFlags.enabled?(:business_tier, for: assigns.current_user)
    owner? = assigns.current_user.id == assigns.site.owner.id
    has_access? = assigns.feature_mod.check_availability(assigns.site.owner) == :ok

    message =
      cond do
        private_preview? && assigns.grandfathered? ->
          "#{assigns.feature_mod.display_name()} is an upcoming premium functionality that's free-to-use during the private preview. Existing subscribers will be grandfathered and will keep having access to this feature without any change to their plan."

        private_preview? ->
          "#{assigns.feature_mod.display_name()} is an upcoming premium functionality that's free-to-use during the private preview. Pricing will be announced soon."

        Plausible.Billing.on_trial?(assigns.site.owner) ->
          "#{assigns.feature_mod.display_name()} is part of the Plausible Business plan. You can access it during your trial, but you'll need to subscribe to the Business plan to retain access after the trial ends."

        not has_access? && owner? ->
          ~H"""
          <%= @feature_mod.display_name() %> is part of the Plausible Business plan. To get access to it, please
          <.link class="underline" href={Routes.billing_path(PlausibleWeb.Endpoint, :upgrade)}>
            upgrade your subscription
          </.link> to the Business plan.
          """

        not has_access? && not owner? ->
          "#{assigns.feature_mod.display_name()} is part of the Plausible Business plan. To get access to it, please reach out to the site owner to upgrade your subscription to the Business plan."

        true ->
          nil
      end

    assigns = assign(assigns, :message, message)

    ~H"""
    <.notice :if={@message} class="rounded-t-md rounded-b-none" size={@size} {@rest}>
      <%= @message %>
    </.notice>
    """
  end

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
      <td class={["py-4 pr-1 text-sm sm:whitespace-nowrap text-left", @pad && "pl-6"]}>
        <%= @title %>
      </td>
      <td class="py-4 text-sm sm:whitespace-nowrap text-right">
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
      <.styled_link href={Routes.billing_path(@conn, :choose_plan)} class="text-sm font-medium">
        <%= upgrade_link_text(@subscription) %>
      </.styled_link>
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
        <.styled_link href={Routes.billing_path(@conn, :upgrade)} class="text-sm font-medium">
          Upgrade
        </.styled_link>
      <% end %>
    </div>
    """
  end

  def subscription_past_due_notice(%{subscription: %Subscription{status: "past_due"}} = assigns) do
    ~H"""
    <aside class={@class}>
      <div class="shadow-md dark:shadow-none rounded-lg bg-yellow-100 p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg
              class="w-5 h-5 mt-0.5 text-yellow-800"
              viewBox="0 0 24 24"
              stroke="currentColor"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              aria-hidden="true"
            >
              <path
                d="M12 9V11M12 15H12.01M5.07183 19H18.9282C20.4678 19 21.4301 17.3333 20.6603 16L13.7321 4C12.9623 2.66667 11.0378 2.66667 10.268 4L3.33978 16C2.56998 17.3333 3.53223 19 5.07183 19Z"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </div>
          <div class="ml-3 flex-1 md:flex md:justify-between">
            <p class="text-yellow-700">
              There was a problem with your latest payment. Please update your payment information to keep using Plausible.
            </p>
            <.link
              href={@subscription.update_url}
              class="whitespace-nowrap font-medium text-yellow-700 hover:text-yellow-600"
            >
              Update billing info <span aria-hidden="true"> &rarr;</span>
            </.link>
          </div>
        </div>
      </div>
    </aside>
    """
  end

  def subscription_past_due_notice(assigns), do: ~H""

  def subscription_paused_notice(%{subscription: %Subscription{status: "paused"}} = assigns) do
    ~H"""
    <aside class={@class}>
      <div class="shadow-md dark:shadow-none rounded-lg bg-red-100 p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg
              class="w-5 h-5 mt-0.5 text-yellow-800"
              viewBox="0 0 24 24"
              stroke="currentColor"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              aria-hidden="true"
            >
              <path
                d="M12 9V11M12 15H12.01M5.07183 19H18.9282C20.4678 19 21.4301 17.3333 20.6603 16L13.7321 4C12.9623 2.66667 11.0378 2.66667 10.268 4L3.33978 16C2.56998 17.3333 3.53223 19 5.07183 19Z"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </div>
          <div class="ml-3 flex-1 md:flex md:justify-between">
            <p class="text-red-700">
              Your subscription is paused due to failed payments. Please provide valid payment details to keep using Plausible.
            </p>
            <.link
              href={@subscription.update_url}
              class="whitespace-nowrap font-medium text-red-700 hover:text-red-600"
            >
              Update billing info <span aria-hidden="true"> &rarr;</span>
            </.link>
          </div>
        </div>
      </div>
    </aside>
    """
  end

  def subscription_paused_notice(assigns), do: ~H""

  def format_price(%Money{} = money) do
    money
    |> Money.to_string!(format: :short, fractional_digits: 2)
    |> String.replace(".00", "")
  end

  defp upgrade_link_text(nil), do: "Upgrade"
  defp upgrade_link_text(_subscription), do: "Change plan"
end
