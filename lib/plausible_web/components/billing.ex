defmodule PlausibleWeb.Components.Billing do
  @moduledoc false

  use Phoenix.Component
  import PlausibleWeb.Components.Generic
  require Plausible.Billing.Subscription.Status
  alias Plausible.Auth.User
  alias Plausible.Billing.Feature.{RevenueGoals, Funnels}
  alias Plausible.Billing.Feature.{Props, StatsAPI}
  alias PlausibleWeb.Router.Helpers, as: Routes
  alias Plausible.Billing.{Subscription, Plans, Plan, Subscriptions}

  attr(:billable_user, User, required: true)
  attr(:current_user, User, required: true)
  attr(:feature_mod, :atom, required: true, values: Plausible.Billing.Feature.list())
  attr(:grandfathered?, :boolean, default: false)
  attr(:size, :atom, default: :sm)
  attr(:rest, :global)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def premium_feature_notice(assigns) do
    legacy_feature_access? =
      Timex.before?(assigns.billable_user.inserted_at, Plans.business_tier_launch()) &&
        assigns.feature_mod in [StatsAPI, Props]

    has_access? = assigns.feature_mod.check_availability(assigns.billable_user) == :ok

    cond do
      legacy_feature_access? ->
        ~H""

      Plausible.Billing.on_trial?(assigns.billable_user) ->
        ~H""

      not has_access? ->
        ~H"""
        <.notice class="rounded-t-md rounded-b-none" size={@size} {@rest} title="Notice">
          <%= account_label(@current_user, @billable_user) %> does not have access to <%= assigns.feature_mod.display_name() %>. To get access to this feature,
          <.upgrade_call_to_action current_user={@current_user} billable_user={@billable_user} />.
        </.notice>
        """

      true ->
        ~H""
    end
  end

  defp private_preview_end do
    private_preview_ends_at = Timex.shift(Plausible.Billing.Plans.business_tier_launch(), days: 8)

    days_remaining = Timex.diff(private_preview_ends_at, NaiveDateTime.utc_now(), :day)

    cond do
      days_remaining <= 0 -> "today"
      days_remaining == 1 -> "tomorrow"
      true -> "in #{days_remaining} days"
    end
  end

  attr(:billable_user, User, required: true)
  attr(:current_user, User, required: true)
  attr(:limit, :integer, required: true)
  attr(:resource, :string, required: true)
  attr(:rest, :global)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def limit_exceeded_notice(assigns) do
    ~H"""
    <.notice {@rest} title="Notice">
      <%= account_label(@current_user, @billable_user) %> is limited to <%= @limit %> <%= @resource %>. To increase this limit,
      <.upgrade_call_to_action current_user={@current_user} billable_user={@billable_user} />.
    </.notice>
    """
  end

  attr(:current_user, :map)
  attr(:billable_user, :map)

  defp upgrade_call_to_action(assigns) do
    billable_user = Plausible.Users.with_subscription(assigns.billable_user)

    plan =
      Plausible.Billing.Plans.get_regular_plan(billable_user.subscription, only_non_expired: true)

    trial? = Plausible.Billing.on_trial?(assigns.billable_user)
    growth? = plan && plan.kind == :growth

    cond do
      assigns.billable_user.id !== assigns.current_user.id ->
        ~H"please reach out to the site owner to upgrade their subscription"

      growth? || trial? ->
        ~H"""
        please
        <.link class="underline inline-block" href={Plausible.Billing.upgrade_route_for(@current_user)}>
          upgrade your subscription
        </.link>
        """

      true ->
        ~H"please contact hello@plausible.io to upgrade your subscription"
    end
  end

  defp account_label(current_user, billable_user) do
    if current_user.id == billable_user.id do
      "Your account"
    else
      "The owner of this site"
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

  attr(:user, :map, required: true)
  attr(:dismissable, :boolean, default: true)

  @doc """
  Given a user with a cancelled subscription, this component renders a cancelled
  subscription notice. If the given user does not have a subscription or it has a
  different status, this function returns an empty template.

  It also takes a dismissable argument which renders the notice dismissable (with
  the help of JavaScript and localStorage). We show a dismissable notice about a
  cancelled subscription across the app, but when the user dismisses it, we will
  start displaying it in the account settings > subscription section instead.

  So it's either shown across the app, or only on the /settings page. Depending
  on whether the localStorage flag to dismiss it has been set or not.
  """
  def subscription_cancelled_notice(assigns)

  def subscription_cancelled_notice(
        %{
          dismissable: true,
          user: %User{subscription: %Subscription{status: Subscription.Status.deleted()}}
        } =
          assigns
      ) do
    ~H"""
    <aside id="global-subscription-cancelled-notice" class="container">
      <PlausibleWeb.Components.Generic.notice
        dismissable_id={Plausible.Billing.cancelled_subscription_notice_dismiss_id(@user)}
        title="Subscription cancelled"
        theme={:red}
        class="shadow-md dark:shadow-none"
      >
        <.subscription_cancelled_notice_body user={@user} />
      </PlausibleWeb.Components.Generic.notice>
    </aside>
    """
  end

  def subscription_cancelled_notice(
        %{
          dismissable: false,
          user: %User{subscription: %Subscription{status: Subscription.Status.deleted()}}
        } =
          assigns
      ) do
    assigns = assign(assigns, :container_id, "local-subscription-cancelled-notice")

    ~H"""
    <aside id={@container_id} class="hidden">
      <PlausibleWeb.Components.Generic.notice
        title="Subscription cancelled"
        theme={:red}
        class="shadow-md dark:shadow-none"
      >
        <.subscription_cancelled_notice_body user={@user} />
      </PlausibleWeb.Components.Generic.notice>
    </aside>
    <script
      data-localstorage-key={"notice_dismissed__#{Plausible.Billing.cancelled_subscription_notice_dismiss_id(assigns.user)}"}
      data-container-id={@container_id}
    >
      const dataset = document.currentScript.dataset

      if (localStorage[dataset.localstorageKey]) {
        document.getElementById(dataset.containerId).classList.remove('hidden')
      }
    </script>
    """
  end

  def subscription_cancelled_notice(assigns), do: ~H""

  attr(:class, :string, default: "")
  attr(:subscription, :any, default: nil)

  def subscription_past_due_notice(
        %{subscription: %Subscription{status: Subscription.Status.past_due()}} = assigns
      ) do
    ~H"""
    <aside class={@class}>
      <PlausibleWeb.Components.Generic.notice
        title="Payment failed"
        class="shadow-md dark:shadow-none"
      >
        There was a problem with your latest payment. Please update your payment information to keep using Plausible.<.link
          href={@subscription.update_url}
          class="whitespace-nowrap font-semibold"
        > Update billing info <span aria-hidden="true"> &rarr;</span></.link>
      </PlausibleWeb.Components.Generic.notice>
    </aside>
    """
  end

  def subscription_past_due_notice(assigns), do: ~H""

  attr(:class, :string, default: "")
  attr(:subscription, :any, default: nil)

  def subscription_paused_notice(
        %{subscription: %Subscription{status: Subscription.Status.paused()}} = assigns
      ) do
    ~H"""
    <aside class={@class}>
      <PlausibleWeb.Components.Generic.notice
        title="Subscription paused"
        theme={:red}
        class="shadow-md dark:shadow-none"
      >
        Your subscription is paused due to failed payments. Please provide valid payment details to keep using Plausible.<.link
          href={@subscription.update_url}
          class="whitespace-nowrap font-semibold"
        > Update billing info <span aria-hidden="true"> &rarr;</span></.link>
      </PlausibleWeb.Components.Generic.notice>
    </aside>
    """
  end

  def subscription_paused_notice(assigns), do: ~H""

  def private_preview_end_notice(assigns) do
    user = assigns.user |> Plausible.Users.with_subscription()

    features_to_lose =
      case Plans.get_subscription_plan(user.subscription) do
        nil ->
          []

        %Plan{kind: :business} ->
          []

        _free_10k_or_enterprise_or_growth ->
          used_features = Plausible.Billing.Quota.features_usage(assigns.user)
          Enum.filter([Funnels, RevenueGoals], &(&1 in used_features))
      end

    assigns = assign(assigns, :features_to_lose, features_to_lose)

    ~H"""
    <div
      :if={FunWithFlags.enabled?(:premium_features_private_preview) && @features_to_lose != []}
      class="container"
    >
      <.notice
        class="shadow-md dark:shadow-none"
        title="Notice"
        dismissable_id={"premium_features_private_preview_end__#{@user.id}"}
      >
        Business plans are now live! The private preview of <%= PlausibleWeb.TextHelpers.pretty_join(
          Enum.map(@features_to_lose, & &1.display_name())
        ) %> ends <b><%= private_preview_end() %></b>. If you wish to continue using <%= if length(
                                                                                              @features_to_lose
                                                                                            ) == 1,
                                                                                            do:
                                                                                              "this feature",
                                                                                            else:
                                                                                              "these features" %>,
        <.upgrade_call_to_action current_user={@user} billable_user={@user} />.
      </.notice>
    </div>
    """
  end

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

  defp subscription_cancelled_notice_body(assigns) do
    if Plausible.Billing.Subscriptions.expired?(assigns.user.subscription) do
      ~H"""
      <.link class="underline inline-block" href={Plausible.Billing.upgrade_route_for(@user)}>
        Upgrade your subscription
      </.link>
      <p>to get access to your stats again.</p>
      """
    else
      ~H"""
      <p>
        You have access to your stats until <span class="font-semibold inline"><%= Timex.format!(@user.subscription.next_bill_date, "{Mshort} {D}, {YYYY}") %></span>.
        <.link class="underline inline-block" href={Plausible.Billing.upgrade_route_for(@user)}>
          Upgrade your subscription
        </.link>
        to make sure you don't lose access.
      </p>
      <.lose_grandfathering_warning user={@user} />
      """
    end
  end

  defp lose_grandfathering_warning(%{user: %{subscription: subscription} = user} = assigns) do
    business_tiers_available? = FunWithFlags.enabled?(:business_tier, for: user)
    plan = Plans.get_regular_plan(subscription, only_non_expired: true)
    loses_grandfathering = business_tiers_available? && plan && plan.generation < 4

    assigns = assign(assigns, :loses_grandfathering, loses_grandfathering)

    ~H"""
    <p :if={@loses_grandfathering} class="mt-2">
      Please also note that by letting your subscription expire, you lose access to our grandfathered terms. If you want to subscribe again after that, your account will be offered the <.link
        href="https://plausible.io/#pricing"
        target="_blank"
        rel="noopener noreferrer"
        class="underline"
      >latest pricing</.link>.
    </p>
    """
  end

  defp change_plan_or_upgrade_text(nil), do: "Upgrade"

  defp change_plan_or_upgrade_text(%Subscription{status: Subscription.Status.deleted()}),
    do: "Upgrade"

  defp change_plan_or_upgrade_text(_subscription), do: "Change plan"
end
