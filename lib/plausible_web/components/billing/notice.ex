defmodule PlausibleWeb.Components.Billing.Notice do
  @moduledoc false

  use PlausibleWeb, :component

  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.{Subscription, Plans, Subscriptions}

  def active_grace_period(assigns) do
    if assigns.enterprise? do
      ~H"""
      <aside class="container">
        <.notice
          title={Plausible.Billing.active_grace_period_notice_title()}
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
          title={Plausible.Billing.active_grace_period_notice_title()}
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
      <.notice
        title={Plausible.Billing.dashboard_locked_notice_title()}
        class="shadow-md dark:shadow-none"
      >
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

  attr(:current_team, :any, required: true)
  attr(:current_user, :atom, required: true)
  attr(:limit, :integer, required: true)
  attr(:resource, :string, required: true)
  attr(:rest, :global)

  def limit_exceeded(assigns) do
    ~H"""
    <.notice {@rest} title="Notice" data-test="limit-exceeded-notice">
      {account_label(@current_team)} is limited to {pretty_print_resource_limit(@limit, @resource)}. To increase this limit,
      <PlausibleWeb.Components.Billing.upgrade_call_to_action
        current_team={@current_team}
        current_user={@current_user}
      />.
    </.notice>
    """
  end

  defp pretty_print_resource_limit(1 = _limit, resource_plural) do
    "a single #{String.trim_trailing(resource_plural, "s")}"
  end

  defp pretty_print_resource_limit(limit, resource_plural) do
    "#{limit} #{resource_plural}"
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
    <aside
      :if={not Subscriptions.expired?(@subscription)}
      id="global-subscription-cancelled-notice"
      class="container"
    >
      <.notice
        dismissable_id={Plausible.Billing.cancelled_subscription_notice_dismiss_id(@subscription.id)}
        title={Plausible.Billing.subscription_cancelled_notice_title()}
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
    <aside :if={not Subscriptions.expired?(@subscription)} id={@container_id} class="hidden">
      <.notice
        title={Plausible.Billing.subscription_cancelled_notice_title()}
        theme={:red}
        class="shadow-md dark:shadow-none"
      >
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
      <.notice
        title={Plausible.Billing.subscription_past_due_notice_title()}
        class="shadow-md dark:shadow-none"
      >
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
      <.notice
        title={Plausible.Billing.subscription_paused_notice_title()}
        theme={:red}
        class="shadow-md dark:shadow-none"
      >
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
      <.notice
        title={Plausible.Billing.upgrade_ineligible_notice_title()}
        theme={:yellow}
        class="shadow-md dark:shadow-none"
      >
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
        <.notice
          title={Plausible.Billing.pending_site_ownerships_notice_title()}
          class="shadow-md dark:shadow-none mt-4"
        >
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
    <div class="mt-8 space-y-3 text-sm leading-6 text-gray-600 text-justify dark:text-gray-100">
      Your subscription has been grandfathered in at the same rate and terms as when you first joined. If you don't need the "Business" features, you're welcome to stay on this plan. You can adjust the pageview limit or change the billing frequency of this grandfathered plan. If you're interested in business features, you can upgrade to a "Business" plan.
    </div>
    """
  end

  @doc """
  Renders a usage notification banner based on the notification type.

  This is used on the subscription settings page to show contextual
  notifications about approaching or exceeded limits.
  """
  attr(:type, :atom, required: true)
  attr(:team, :any, required: true)

  def usage_notification(assigns)

  def usage_notification(%{type: :pageview_approaching_limit} = assigns) do
    ~H"""
    <.notice title="You're close to your monthly pageview limit" theme={:gray} show_icon={false}>
      <div class="flex flex-col gap-4">
        <p class="text-pretty">
          No action is required. Occasional traffic spikes are normal, and we'll keep tracking your stats as usual. Upgrading now gives you room to grow if higher traffic continues.
        </p>
        <div class="flex gap-3 items-center">
          <.button_link href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)} mt?={false}>
            Upgrade
          </.button_link>
          <.button_link
            href="https://plausible.io/docs/subscription-plans"
            theme="secondary"
            mt?={false}
          >
            Learn more
          </.button_link>
        </div>
      </div>
    </.notice>
    """
  end

  def usage_notification(%{type: :team_member_limit_reached} = assigns) do
    ~H"""
    <.notice title="You've reached your current team member limit" theme={:gray} show_icon={false}>
      <div class="flex flex-col gap-4 items-start">
        <p class="text-pretty">
          Upgrading lets you add more as your team grows.
        </p>
        <.button_link href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)} mt?={false}>
          Upgrade
        </.button_link>
      </div>
    </.notice>
    """
  end

  def usage_notification(%{type: :site_limit_reached} = assigns) do
    ~H"""
    <.notice title="You've reached your current site limit" theme={:gray} show_icon={false}>
      <div class="flex flex-col gap-4 items-start">
        <p class="text-pretty">
          Upgrading lets you add more sites as you grow.
        </p>
        <.button_link href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)} mt?={false}>
          Upgrade
        </.button_link>
      </div>
    </.notice>
    """
  end

  def usage_notification(%{type: :site_and_team_member_limit_reached} = assigns) do
    ~H"""
    <.notice
      title="You've reached your current limits for team members and sites"
      theme={:gray}
      show_icon={false}
    >
      <div class="flex flex-col gap-4 items-start">
        <p class="text-pretty">
          Upgrading gives you room to grow.
        </p>
        <.button_link href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)} mt?={false}>
          Upgrade
        </.button_link>
      </div>
    </.notice>
    """
  end

  def usage_notification(%{type: :traffic_exceeded_last_cycle} = assigns) do
    ~H"""
    <.notice title="Traffic exceeded your plan limit last cycle" theme={:gray} show_icon={false}>
      <div class="flex flex-col gap-4">
        <p class="text-pretty">
          No action is required. Occasional traffic spikes are normal, but upgrading now gives you room to grow if higher traffic continues.
        </p>
        <div class="flex gap-3 items-center">
          <.button_link href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)} mt?={false}>
            Upgrade
          </.button_link>
          <.button_link
            href="https://plausible.io/docs/subscription-plans"
            theme="secondary"
            mt?={false}
          >
            Learn more
          </.button_link>
        </div>
      </div>
    </.notice>
    """
  end

  def usage_notification(%{type: :traffic_exceeded_sustained} = assigns) do
    ~H"""
    <.notice title="Upgrade required due to sustained higher traffic" theme={:gray} show_icon={false}>
      <div class="flex flex-col gap-4">
        <p class="text-pretty">
          To ensure uninterrupted access to your stats, please upgrade to a plan that fits your current usage.
        </p>
        <div class="flex gap-3 items-center">
          <.button_link href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)} mt?={false}>
            Upgrade
          </.button_link>
          <.button_link
            href="https://plausible.io/docs/subscription-plans"
            theme="secondary"
            mt?={false}
          >
            Learn more
          </.button_link>
        </div>
      </div>
    </.notice>
    """
  end

  def usage_notification(%{type: :manual_lock_grace_period_active} = assigns) do
    ~H"""
    <.notice title="You've outgrown your custom plan" theme={:yellow} show_icon={false}>
      <p class="text-pretty">
        We'll contact you by email to discuss an updated custom plan based on your current usage.
      </p>
    </.notice>
    """
  end

  def usage_notification(%{type: :grace_period_active, team: team} = assigns) do
    deadline_text =
      case Plausible.Teams.GracePeriod.expires_in(team) do
        {0, :hours} -> "within the hour"
        {1, :hours} -> "within the next hour"
        {n, :hours} -> "within the next #{n} hours"
        {n, :days} -> "within the next #{n} days"
      end

    assigns = assign(assigns, :deadline_text, deadline_text)

    ~H"""
    <.notice title="Upgrade required due to sustained higher traffic" theme={:gray} show_icon={false}>
      <div class="flex flex-col gap-4">
        <p class="text-pretty">
          To ensure uninterrupted access to your stats, please upgrade to a plan that fits your current usage {@deadline_text}.
        </p>
        <div class="flex gap-3 items-center">
          <.button_link href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)} mt?={false}>
            Upgrade
          </.button_link>
          <.button_link
            href="https://plausible.io/docs/subscription-plans"
            theme="secondary"
            mt?={false}
          >
            Learn more
          </.button_link>
        </div>
      </div>
    </.notice>
    """
  end

  def usage_notification(%{type: :dashboard_locked} = assigns) do
    ~H"""
    <.notice title="Dashboard access temporarily locked" theme={:gray} show_icon={false}>
      <div class="flex flex-col gap-4">
        <p class="text-pretty">
          Your stats are still being tracked, but dashboard access is temporarily locked because your site exceeded your plan's pageview limit for two consecutive billing cycles. Upgrade to restore access.
        </p>
        <div class="flex gap-3 items-center">
          <.button_link href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)} mt?={false}>
            Upgrade
          </.button_link>
          <.button_link
            href="https://plausible.io/docs/subscription-plans"
            theme="secondary"
            mt?={false}
          >
            Learn more
          </.button_link>
        </div>
      </div>
    </.notice>
    """
  end

  def usage_notification(%{type: :trial_ended} = assigns) do
    ~H"""
    <.notice title="Your free trial has ended" theme={:gray} show_icon={false}>
      <div class="flex flex-col gap-4 items-start">
        <p class="text-pretty">
          Upgrade to a monthly or yearly plan to continue accessing your sites.
        </p>
        <.button_link href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)} mt?={false}>
          Choose a plan
        </.button_link>
      </div>
    </.notice>
    """
  end

  def usage_notification(assigns), do: ~H""

  defp subscription_cancelled_notice_body(assigns) do
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

  defp lose_grandfathering_warning(%{subscription: subscription} = assigns) do
    plan = Plans.get_regular_plan(subscription, only_non_expired: true)
    loses_grandfathering? = plan && plan.generation < 5

    assigns = assign(assigns, :loses_grandfathering?, loses_grandfathering?)

    ~H"""
    <p :if={@loses_grandfathering?} class="mt-2">
      Please also note that by letting your subscription expire, you lose access to our grandfathered terms. If you want to subscribe again after that, your account will be offered the <.link
        href="https://plausible.io/#pricing"
        target="_blank"
        rel="noopener noreferrer"
        class="underline"
      >latest pricing</.link>.
    </p>
    """
  end

  defp account_label(%Plausible.Teams.Team{setup_complete: true}), do: "This team"
  defp account_label(_team), do: "This account"
end
