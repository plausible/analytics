defmodule PlausibleWeb.Components.Billing.Notice do
  @moduledoc false

  use PlausibleWeb, :component

  require Plausible.Billing.Subscription.Status
  alias Plausible.Auth.User
  alias Plausible.Billing.{Subscription, Plans, Subscriptions, Feature}

  def active_grace_period(assigns) do
    if assigns.enterprise? do
      ~H"""
      <aside class="container">
        <.notice
          title="You have outgrown your Plausible subscription tier"
          class="shadow-md dark:shadow-none"
        >
          To keep your stats running smoothly, it’s time to upgrade your subscription to match your growing usage.
          <.link
            href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
            class="whitespace-nowrap font-semibold"
          >
            Upgrade now <span aria-hidden="true"> &rarr;</span>
          </.link>
        </.notice>
      </aside>
      """
    else
      ~H"""
      <aside class="container">
        <.notice
          title="You have outgrown your Plausible subscription tier"
          class="shadow-md dark:shadow-none"
        >
          To keep your stats running smoothly, it’s time to upgrade your subscription to match your growing usage.
          <.link
            href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
            class="whitespace-nowrap font-semibold"
          >
            Upgrade now <span aria-hidden="true"> &rarr;</span>
          </.link>
        </.notice>
      </aside>
      """
    end
  end

  def dashboard_locked(assigns) do
    ~H"""
    <aside class="container">
      <.notice title="Dashboard locked" class="shadow-md dark:shadow-none">
        Since you’ve outgrown your current subscription tier, it’s time to upgrade to match your growing usage.
        <.link
          href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
          class="whitespace-nowrap font-semibold"
        >
          Upgrade now <span aria-hidden="true"> &rarr;</span>
        </.link>
      </.notice>
    </aside>
    """
  end

  attr(:billable_user, User, required: true)
  attr(:current_user, User, required: true)
  attr(:current_team, :any, required: true)
  attr(:feature_mod, :atom, required: true, values: Feature.list())
  attr(:grandfathered?, :boolean, default: false)
  attr(:rest, :global)

  def premium_feature(assigns) do
    ~H"""
    <.notice
      :if={@feature_mod.check_availability(@current_team) !== :ok}
      class="rounded-t-md rounded-b-none"
      title="Notice"
      {@rest}
    >
      {account_label(@current_user, @billable_user)} does not have access to {@feature_mod.display_name()}. To get access to this feature,
      <.upgrade_call_to_action
        current_team={@current_team}
        current_user={@current_user}
        billable_user={@billable_user}
      />.
    </.notice>
    """
  end

  attr(:billable_user, User, required: true)
  attr(:current_user, User, required: true)
  attr(:current_team, :any, required: true)
  attr(:limit, :integer, required: true)
  attr(:resource, :string, required: true)
  attr(:rest, :global)

  def limit_exceeded(assigns) do
    ~H"""
    <.notice {@rest} title="Notice">
      {account_label(@current_user, @billable_user)} is limited to {@limit} {@resource}. To increase this limit,
      <.upgrade_call_to_action
        current_team={@current_team}
        current_user={@current_user}
        billable_user={@billable_user}
      />.
    </.notice>
    """
  end

  attr(:subscription, :map, required: true)
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
  def subscription_cancelled(assigns)

  def subscription_cancelled(
        %{
          dismissable: true,
          subscription: %Subscription{status: Subscription.Status.deleted()}
        } = assigns
      ) do
    ~H"""
    <aside id="global-subscription-cancelled-notice" class="container">
      <.notice
        dismissable_id={Plausible.Billing.cancelled_subscription_notice_dismiss_id(@subscription.id)}
        title="Subscription cancelled"
        theme={:red}
        class="shadow-md dark:shadow-none"
      >
        <.subscription_cancelled_notice_body subscription={@subscription} />
      </.notice>
    </aside>
    """
  end

  def subscription_cancelled(
        %{
          dismissable: false,
          subscription: %Subscription{status: Subscription.Status.deleted()}
        } = assigns
      ) do
    assigns = assign(assigns, :container_id, "local-subscription-cancelled-notice")

    ~H"""
    <aside id={@container_id} class="hidden">
      <.notice title="Subscription cancelled" theme={:red} class="shadow-md dark:shadow-none">
        <.subscription_cancelled_notice_body subscription={@subscription} />
      </.notice>
    </aside>
    <script
      data-localstorage-key={"notice_dismissed__#{Plausible.Billing.cancelled_subscription_notice_dismiss_id(@subscription.id)}"}
      data-container-id={@container_id}
    >
      const dataset = document.currentScript.dataset

      if (localStorage[dataset.localstorageKey]) {
        document.getElementById(dataset.containerId).classList.remove('hidden')
      }
    </script>
    """
  end

  def subscription_cancelled(assigns), do: ~H""

  attr(:class, :string, default: "")
  attr(:subscription, :any, default: nil)

  def subscription_past_due(
        %{subscription: %Subscription{status: Subscription.Status.past_due()}} = assigns
      ) do
    ~H"""
    <aside class={@class}>
      <.notice title="Payment failed" class="shadow-md dark:shadow-none">
        There was a problem with your latest payment. Please update your payment information to keep using Plausible.<.link
          href={@subscription.update_url}
          class="whitespace-nowrap font-semibold"
        > Update billing info <span aria-hidden="true"> &rarr;</span></.link>
      </.notice>
    </aside>
    """
  end

  def subscription_past_due(assigns), do: ~H""

  attr(:class, :string, default: "")
  attr(:subscription, :any, default: nil)

  def subscription_paused(
        %{subscription: %Subscription{status: Subscription.Status.paused()}} = assigns
      ) do
    ~H"""
    <aside class={@class}>
      <.notice title="Subscription paused" theme={:red} class="shadow-md dark:shadow-none">
        Your subscription is paused due to failed payments. Please provide valid payment details to keep using Plausible.<.link
          href={@subscription.update_url}
          class="whitespace-nowrap font-semibold"
        > Update billing info <span aria-hidden="true"> &rarr;</span></.link>
      </.notice>
    </aside>
    """
  end

  def subscription_paused(assigns), do: ~H""

  def upgrade_ineligible(assigns) do
    ~H"""
    <aside id="upgrade-eligible-notice" class="pb-6">
      <.notice title="No sites owned" theme={:yellow} class="shadow-md dark:shadow-none">
        You cannot start a subscription as your account doesn't own any sites. The account that owns the sites is responsible for the billing. Please either
        <.styled_link href="https://plausible.io/docs/transfer-ownership">
          transfer the sites
        </.styled_link>
        to your account or start a subscription from the account that owns your sites.
      </.notice>
    </aside>
    """
  end

  def pending_site_ownerships_notice(%{pending_ownership_count: count} = assigns) do
    if count > 0 do
      message =
        "Your account has been invited to become the owner of " <>
          if(count == 1, do: "a site, which is", else: "#{count} sites, which are") <>
          " being counted towards the usage of your account."

      assigns = assign(assigns, message: message)

      ~H"""
      <aside class={@class}>
        <.notice title="Pending ownership transfers" class="shadow-md dark:shadow-none mt-4">
          {@message} To exclude pending sites from your usage, please go to
          <.link href="https://plausible.io/sites" class="whitespace-nowrap font-semibold">
            plausible.io/sites
          </.link>
          and reject the invitations.
        </.notice>
      </aside>
      """
    else
      ~H""
    end
  end

  def growth_grandfathered(assigns) do
    ~H"""
    <div class="mt-8 space-y-3 text-sm leading-6 text-gray-600 text-justify dark:text-gray-100 xl:mt-10">
      Your subscription has been grandfathered in at the same rate and terms as when you first joined. If you don't need the "Business" features, you're welcome to stay on this plan. You can adjust the pageview limit or change the billing frequency of this grandfathered plan. If you're interested in business features, you can upgrade to the new "Business" plan.
    </div>
    """
  end

  defp subscription_cancelled_notice_body(assigns) do
    if Subscriptions.expired?(assigns.subscription) do
      ~H"""
      <.link
        class="underline inline-block"
        href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
      >
        Upgrade your subscription
      </.link>
      to get access to your stats again.
      """
    else
      ~H"""
      <p>
        You have access to your stats until <span class="font-semibold inline"><%= Calendar.strftime(@subscription.next_bill_date, "%b %-d, %Y") %></span>.
        <.link
          class="underline inline-block"
          href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
        >
          Upgrade your subscription
        </.link>
        to make sure you don't lose access.
      </p>
      <.lose_grandfathering_warning subscription={@subscription} />
      """
    end
  end

  defp lose_grandfathering_warning(%{subscription: subscription} = assigns) do
    plan = Plans.get_regular_plan(subscription, only_non_expired: true)
    loses_grandfathering = plan && plan.generation < 4

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

  attr(:current_user, :map)
  attr(:current_team, :any)
  attr(:billable_user, :map)

  defp upgrade_call_to_action(assigns) do
    team = Plausible.Teams.with_subscription(assigns.current_team)

    upgrade_assistance_required? =
      case Plans.get_subscription_plan(team && team.subscription) do
        %Plausible.Billing.Plan{kind: :business} -> true
        %Plausible.Billing.EnterprisePlan{} -> true
        _ -> false
      end

    cond do
      assigns.billable_user.id !== assigns.current_user.id ->
        ~H"please reach out to the site owner to upgrade their subscription"

      upgrade_assistance_required? ->
        ~H"""
        please contact <a href="mailto:hello@plausible.io" class="underline">hello@plausible.io</a>
        to upgrade your subscription
        """

      true ->
        ~H"""
        please
        <.link
          class="underline inline-block"
          href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
        >
          upgrade your subscription
        </.link>
        """
    end
  end

  defp account_label(current_user, billable_user) do
    if current_user.id == billable_user.id do
      "Your account"
    else
      "The owner of this site"
    end
  end
end
