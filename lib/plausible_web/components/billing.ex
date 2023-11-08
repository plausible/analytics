defmodule PlausibleWeb.Components.Billing do
  @moduledoc false

  use Phoenix.Component
  import PlausibleWeb.Components.Generic
  require Plausible.Billing.Subscription.Status
  alias PlausibleWeb.Router.Helpers, as: Routes
  alias Plausible.Billing.{Subscription, Plans, Subscriptions}

  attr(:billable_user, Plausible.Auth.User, required: true)
  attr(:current_user, Plausible.Auth.User, required: true)
  attr(:feature_mod, :atom, required: true, values: Plausible.Billing.Feature.list())
  attr(:grandfathered?, :boolean, default: false)
  attr(:size, :atom, default: :sm)
  attr(:rest, :global)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def premium_feature_notice(assigns) do
    billable_user = Plausible.Users.with_subscription(assigns.billable_user)
    plan = Plans.get_regular_plan(billable_user.subscription, only_non_expired: true)
    growth? = plan && plan.kind == :growth

    private_preview? = FunWithFlags.enabled?(:premium_features_private_preview)
    display_upgrade_link? = assigns.current_user.id == assigns.billable_user.id
    has_access? = assigns.feature_mod.check_availability(assigns.billable_user) == :ok

    message =
      cond do
        Plausible.Billing.on_trial?(assigns.billable_user) ->
          "#{assigns.feature_mod.display_name()} is part of the Plausible Business plan. You can access it during your trial, but you'll need to subscribe to the Business plan to retain access after the trial ends."

        private_preview? && display_upgrade_link? && growth? ->
          ~H"""
          Business plans are now live! The private preview of <%= @feature_mod.display_name() %> for Plausible Growth plans ends <%= private_preview_days_remaining() %>. If you wish to continue using this feature, please
          <.link class="underline" href={Routes.billing_path(PlausibleWeb.Endpoint, :upgrade)}>
            upgrade your subscription
          </.link> to the Plausible Business plan.
          """

        not has_access? && display_upgrade_link? ->
          ~H"""
          <%= @feature_mod.display_name() %> is part of the Plausible Business plan. To get access to it, please
          <.link class="underline inline-block" href={Plausible.Billing.upgrade_route_for(@current_user)}>
            upgrade your subscription
          </.link> to the Business plan.
          """

        not has_access? && not display_upgrade_link? ->
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

  attr(:billable_user, Plausible.Auth.User, required: true)
  attr(:current_user, Plausible.Auth.User, required: true)
  attr(:limit, :integer, required: true)
  attr(:resource, :string, required: true)
  attr(:rest, :global)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def limit_exceeded_notice(assigns) do
    billable_user = Plausible.Users.with_subscription(assigns.billable_user)

    plan =
      Plausible.Billing.Plans.get_regular_plan(billable_user.subscription, only_non_expired: true)

    trial? = Plausible.Billing.on_trial?(assigns.billable_user)
    growth? = plan && plan.kind == :growth

    display_upgrade_link? = assigns.current_user.id == assigns.billable_user.id

    message =
      cond do
        !display_upgrade_link? ->
          "This account is limited to #{assigns.limit} #{assigns.resource}. To increase this limit, please reach out to the site owner to upgrade their subscription"

        growth? || trial? ->
          ~H"""
          Your account is limited to <%= @limit %> <%= @resource %>. To increase this limit, please
          <.link class="underline inline-block" href={Plausible.Billing.upgrade_route_for(@current_user)}>
            upgrade your subscription
          </.link> to the Business plan.
          """

        true ->
          "Your account is limited to #{assigns.limit} #{assigns.resource}. To increase this limit, please contact support@plausible.io about the Enterprise plan"
      end

    assigns = assign(assigns, :message, message)

    ~H"""
    <.notice :if={@message} {@rest}>
      <%= @message %>
    </.notice>
    """
  end

  defp private_preview_days_remaining do
    private_preview_ends_at = Timex.shift(Plausible.Billing.Plans.business_tier_launch(), days: 7)

    days_remaining = Timex.diff(private_preview_ends_at, NaiveDateTime.utc_now(), :day)

    if days_remaining <= 0 do
      "today"
    else
      "in #{days_remaining} days"
    end
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
      id="monthly-quota-box"
      class="h-32 px-2 py-4 my-4 text-center bg-gray-100 rounded dark:bg-gray-900"
      style="width: 11.75rem;"
    >
      <h4 class="font-black dark:text-gray-100">Monthly quota</h4>
      <div class="py-2 text-xl font-medium dark:text-gray-100">
        <%= PlausibleWeb.AuthView.subscription_quota(@subscription, format: :long) %>
      </div>
      <.styled_link
        :if={
          not (Plausible.Auth.enterprise_configured?(@user) && Subscriptions.halted?(@subscription))
        }
        id="#upgrade-or-change-plan-link"
        href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
        class="text-sm font-medium"
      >
        <%= change_plan_or_upgrade_text(@subscription) %>
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
          :if={@subscription.status == Subscription.Status.active()}
          href={Routes.billing_path(PlausibleWeb.Endpoint, :change_plan_form)}
          class="text-sm font-medium"
        >
          Change plan
        </.styled_link>

        <span
          :if={@subscription.status == Subscription.Status.past_due()}
          class="text-sm text-gray-600 dark:text-gray-400 font-medium"
          tooltip="Please update your billing details before changing plans"
        >
          Change plan
        </span>
      <% else %>
        <div class="py-2 text-xl font-medium dark:text-gray-100">Free trial</div>
        <.styled_link
          href={Routes.billing_path(PlausibleWeb.Endpoint, :upgrade)}
          class="text-sm font-medium"
        >
          Upgrade
        </.styled_link>
      <% end %>
    </div>
    """
  end

  def subscription_past_due_notice(
        %{subscription: %Subscription{status: Subscription.Status.past_due()}} = assigns
      ) do
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

  def subscription_paused_notice(
        %{subscription: %Subscription{status: Subscription.Status.paused()}} = assigns
      ) do
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

  def present_enterprise_plan(assigns) do
    ~H"""
    <ul class="w-full py-4">
      <li>
        Up to <b><%= present_limit(@plan, :monthly_pageview_limit) %></b> monthly pageviews
      </li>
      <li>
        Up to <b><%= present_limit(@plan, :site_limit) %></b> sites
      </li>
      <li>
        Up to <b><%= present_limit(@plan, :hourly_api_request_limit) %></b> hourly api requests
      </li>
    </ul>
    """
  end

  defp present_limit(enterprise_plan, key) do
    enterprise_plan
    |> Map.fetch!(key)
    |> PlausibleWeb.StatsView.large_number_format()
  end

  @spec format_price(Money.t()) :: String.t()
  def format_price(money) do
    Money.to_string!(money, fractional_digits: 2, no_fraction_if_integer: true)
  end

  attr :id, :string, required: true
  attr :paddle_product_id, :string, required: true
  attr :checkout_disabled, :boolean, default: false
  attr :user, :map, required: true
  attr :confirm_message, :any, default: nil
  slot :inner_block, required: true

  def paddle_button(assigns) do
    confirmed =
      if assigns.confirm_message, do: "confirm(\"#{assigns.confirm_message}\")", else: "true"

    assigns = assign(assigns, :confirmed, confirmed)

    ~H"""
    <button
      id={@id}
      onclick={"if (#{@confirmed}) {Paddle.Checkout.open(#{Jason.encode!(%{product: @paddle_product_id, email: @user.email, disableLogout: true, passthrough: @user.id, success: Routes.billing_path(PlausibleWeb.Endpoint, :upgrade_success), theme: "none"})})}"}
      class={[
        "w-full mt-6 block rounded-md py-2 px-3 text-center text-sm font-semibold leading-6 text-white",
        !@checkout_disabled && "bg-indigo-600 hover:bg-indigo-500",
        @checkout_disabled && "pointer-events-none bg-gray-400 dark:bg-gray-600"
      ]}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  def paddle_script(assigns) do
    ~H"""
    <script type="text/javascript" src="https://cdn.paddle.com/paddle/paddle.js">
    </script>
    <script :if={Application.get_env(:plausible, :environment) == "dev"}>
      Paddle.Environment.set('sandbox')
    </script>
    <script>
      Paddle.Setup({vendor: <%= Application.get_env(:plausible, :paddle) |> Keyword.fetch!(:vendor_id) %> })
    </script>
    """
  end

  def upgrade_link(%{business_tier: true} = assigns) do
    ~H"""
    <PlausibleWeb.Components.Generic.button_link
      id="upgrade-link-2"
      href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
    >
      Upgrade
    </PlausibleWeb.Components.Generic.button_link>
    """
  end

  def upgrade_link(assigns) do
    ~H"""
    <PlausibleWeb.Components.Generic.button_link href={
      Routes.billing_path(PlausibleWeb.Endpoint, :upgrade)
    }>
      Upgrade
    </PlausibleWeb.Components.Generic.button_link>
    """
  end

  defp change_plan_or_upgrade_text(nil), do: "Upgrade"

  defp change_plan_or_upgrade_text(%Subscription{status: Subscription.Status.deleted()}),
    do: "Upgrade"

  defp change_plan_or_upgrade_text(_subscription), do: "Change plan"
end
