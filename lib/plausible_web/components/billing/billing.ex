defmodule PlausibleWeb.Components.Billing do
  @moduledoc false

  use PlausibleWeb, :component
  use Plausible

  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.{Subscription, Subscriptions, Plan, Plans, EnterprisePlan}

  attr :current_role, :atom, required: true
  attr :current_team, :any, required: true
  attr :locked?, :boolean, required: true
  slot :inner_block, required: true

  def feature_gate(assigns) do
    ~H"""
    <div id="feature-gate-inner-block-container" class={if(@locked?, do: "pointer-events-none")}>
      {render_slot(@inner_block)}
    </div>
    <div
      :if={@locked?}
      id="feature-gate-overlay"
      class="absolute backdrop-blur-[6px] bg-white/50 dark:bg-gray-800/50 inset-0 flex justify-center items-center rounded-md"
    >
      <div class="px-6 flex flex-col items-center text-gray-500 dark:text-gray-400">
        <Heroicons.lock_closed solid class="size-8 mb-2" />

        <span id="lock-notice" class="text-center max-w-sm sm:max-w-md">
          To gain access to this feature,
          <.upgrade_call_to_action current_role={@current_role} current_team={@current_team} />.
        </span>
      </div>
    </div>
    """
  end

  def render_monthly_pageview_usage(%{usage: usage} = assigns)
      when is_map_key(usage, :last_30_days) do
    ~H"""
    <.monthly_pageview_usage_table usage={@usage.last_30_days} limit={@limit} period={:last_30_days} />
    """
  end

  def render_monthly_pageview_usage(assigns) do
    ~H"""
    <article id="monthly_pageview_usage_container" x-data="{ tab: 'last_cycle' }" class="mt-8">
      <.title>Monthly pageviews usage</.title>
      <div class="mt-4 mb-4">
        <ol class="divide-y divide-gray-300 dark:divide-gray-600 rounded-md border dark:border-gray-600 md:flex md:flex-row-reverse md:divide-y-0 md:overflow-hidden">
          <.billing_cycle_tab
            name="Upcoming cycle"
            tab={:current_cycle}
            date_range={@usage.current_cycle.date_range}
            with_separator={true}
          />
          <.billing_cycle_tab
            name="Last cycle"
            tab={:last_cycle}
            date_range={@usage.last_cycle.date_range}
            with_separator={true}
          />
          <.billing_cycle_tab
            name="Penultimate cycle"
            tab={:penultimate_cycle}
            date_range={@usage.penultimate_cycle.date_range}
            disabled={@usage.penultimate_cycle.total == 0}
          />
        </ol>
      </div>
      <div x-show="tab === 'current_cycle'">
        <.monthly_pageview_usage_table
          usage={@usage.current_cycle}
          limit={@limit}
          period={:current_cycle}
        />
      </div>
      <div x-show="tab === 'last_cycle'">
        <.monthly_pageview_usage_table usage={@usage.last_cycle} limit={@limit} period={:last_cycle} />
      </div>
      <div x-show="tab === 'penultimate_cycle'">
        <.monthly_pageview_usage_table
          usage={@usage.penultimate_cycle}
          limit={@limit}
          period={:penultimate_cycle}
        />
      </div>
    </article>
    """
  end

  attr(:usage, :map, required: true)
  attr(:limit, :any, required: true)
  attr(:period, :atom, required: true)

  defp monthly_pageview_usage_table(assigns) do
    ~H"""
    <.usage_and_limits_table>
      <.usage_and_limits_row
        id={"total_pageviews_#{@period}"}
        title={"Total billable pageviews#{if @period == :last_30_days, do: " (last 30 days)"}"}
        usage={@usage.total}
        limit={@limit}
      />
      <.usage_and_limits_row
        id={"pageviews_#{@period}"}
        pad
        title="Pageviews"
        usage={@usage.pageviews}
      />
      <.usage_and_limits_row
        id={"custom_events_#{@period}"}
        pad
        title="Custom events"
        usage={@usage.custom_events}
      />
    </.usage_and_limits_table>
    """
  end

  attr(:name, :string, required: true)
  attr(:date_range, :any, required: true)
  attr(:tab, :atom, required: true)
  attr(:disabled, :boolean, default: false)
  attr(:with_separator, :boolean, default: false)

  defp billing_cycle_tab(assigns) do
    ~H"""
    <li id={"billing_cycle_tab_#{@tab}"} class="relative md:w-1/3">
      <button
        class={["w-full group", @disabled && "pointer-events-none opacity-50 dark:opacity-25"]}
        x-on:click={"tab = '#{@tab}'"}
      >
        <span
          class="absolute left-0 top-0 h-full w-1 md:bottom-0 md:top-auto md:h-1 md:w-full"
          x-bind:class={"tab === '#{@tab}' ? 'bg-indigo-500' : 'bg-transparent group-hover:bg-gray-200 dark:group-hover:bg-gray-700 '"}
          aria-hidden="true"
        >
        </span>
        <div class={"flex items-center justify-between md:flex-col md:items-start py-2 pr-2 #{if @with_separator, do: "pl-2 md:pl-4", else: "pl-2"}"}>
          <span
            class="text-sm dark:text-gray-100"
            x-bind:class={"tab === '#{@tab}' ? 'text-indigo-600 dark:text-indigo-500 font-semibold' : 'font-medium'"}
          >
            {@name}
          </span>
          <span class="flex text-xs text-gray-500 dark:text-gray-400">
            {if @disabled,
              do: "Not available",
              else: PlausibleWeb.TextHelpers.format_date_range(@date_range)}
          </span>
        </div>
      </button>
      <div
        :if={@with_separator}
        class="absolute inset-0 left-0 top-0 w-3 hidden md:block"
        aria-hidden="true"
      >
        <svg
          class="h-full w-full text-gray-300 dark:text-gray-600"
          viewBox="0 0 12 82"
          fill="none"
          preserveAspectRatio="none"
        >
          <path
            d="M0.5 0V31L10.5 41L0.5 51V82"
            stroke="currentcolor"
            vector-effect="non-scaling-stroke"
          />
        </svg>
      </div>
    </li>
    """
  end

  slot(:inner_block, required: true)
  attr(:rest, :global)

  def usage_and_limits_table(assigns) do
    ~H"""
    <table class="min-w-full text-gray-900 dark:text-gray-100" {@rest}>
      <tbody class="divide-y divide-gray-200 dark:divide-gray-600">
        {render_slot(@inner_block)}
      </tbody>
    </table>
    """
  end

  attr(:title, :string, required: true)
  attr(:usage, :integer, required: true)
  attr(:limit, :integer, default: nil)
  attr(:pad, :boolean, default: false)
  attr(:rest, :global)

  def usage_and_limits_row(assigns) do
    ~H"""
    <tr {@rest}>
      <td class={["text-sm py-4 pr-1 sm:whitespace-nowrap text-left", @pad && "pl-6"]}>
        {@title}
      </td>
      <td class="text-sm py-4 sm:whitespace-nowrap text-right">
        {PlausibleWeb.TextHelpers.number_format(@usage)}
        {if is_number(@limit), do: "/ #{PlausibleWeb.TextHelpers.number_format(@limit)}"}
      </td>
    </tr>
    """
  end

  def monthly_quota_box(assigns) do
    ~H"""
    <div
      id="monthly-quota-box"
      class="w-full flex-1 h-32 px-2 py-4 text-center bg-gray-100 rounded dark:bg-gray-900 w-max-md"
    >
      <h4 class="font-black dark:text-gray-100">Monthly quota</h4>
      <div class="py-2 text-xl font-medium dark:text-gray-100">
        {PlausibleWeb.AuthView.subscription_quota(@subscription, format: :long)}
      </div>
      <.styled_link
        :if={
          not (Plausible.Teams.Billing.enterprise_configured?(@team) &&
                 Subscriptions.halted?(@subscription))
        }
        id="#upgrade-or-change-plan-link"
        href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
      >
        {change_plan_or_upgrade_text(@subscription)}
      </.styled_link>
    </div>
    """
  end

  def present_enterprise_plan(assigns) do
    ~H"""
    <ul class="w-full py-4">
      <li>
        Up to <b>{present_limit(@plan, :monthly_pageview_limit)}</b> monthly pageviews
      </li>
      <li>
        Up to <b>{present_limit(@plan, :site_limit)}</b> sites
      </li>
      <li>
        Up to <b>{present_limit(@plan, :hourly_api_request_limit)}</b> hourly api requests
      </li>
    </ul>
    """
  end

  defp present_limit(enterprise_plan, key) do
    enterprise_plan
    |> Map.fetch!(key)
    |> PlausibleWeb.StatsView.large_number_format()
  end

  attr :id, :string, required: true
  attr :paddle_product_id, :string, required: true
  attr :checkout_disabled, :boolean, default: false
  attr :user, :map, required: true
  attr :team, :map, default: nil
  attr :confirm_message, :any, default: nil
  slot :inner_block, required: true

  def paddle_button(assigns) do
    js_action_expr =
      start_paddle_checkout_expr(assigns.paddle_product_id, assigns.team, assigns.user)

    confirmed =
      if assigns.confirm_message, do: "confirm(\"#{assigns.confirm_message}\")", else: "true"

    assigns =
      assigns
      |> assign(:confirmed, confirmed)
      |> assign(:js_action_expr, js_action_expr)

    ~H"""
    <button
      id={@id}
      onclick={"if (#{@confirmed}) {#{@js_action_expr}}"}
      class={[
        "text-sm w-full mt-6 block rounded-md py-2 px-3 text-center font-semibold leading-6 text-white",
        !@checkout_disabled && "bg-indigo-600 hover:bg-indigo-500",
        @checkout_disabled && "pointer-events-none bg-gray-400 dark:bg-gray-600"
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  if Mix.env() == :dev do
    def start_paddle_checkout_expr(paddle_product_id, _team, _user) do
      "window.location = '#{Routes.dev_subscription_path(PlausibleWeb.Endpoint, :create_form, paddle_product_id)}'"
    end

    def paddle_script(assigns), do: ~H""
  else
    def start_paddle_checkout_expr(paddle_product_id, team, user) do
      passthrough =
        if team do
          "ee:#{ee?()};user:#{user.id};team:#{team.id}"
        else
          "ee:#{ee?()};user:#{user.id}"
        end

      paddle_checkout_params =
        Jason.encode!(%{
          product: paddle_product_id,
          email: user.email,
          disableLogout: true,
          passthrough: passthrough,
          success: Routes.billing_path(PlausibleWeb.Endpoint, :upgrade_success),
          theme: "none"
        })

      "Paddle.Checkout.open(#{paddle_checkout_params})"
    end

    def paddle_script(assigns) do
      ~H"""
      <script type="text/javascript" src="https://cdn.paddle.com/paddle/paddle.js">
      </script>
      <script :if={Application.get_env(:plausible, :environment) == "staging"}>
        Paddle.Environment.set('sandbox')
      </script>
      <script>
        Paddle.Setup({vendor: <%= Application.get_env(:plausible, :paddle) |> Keyword.fetch!(:vendor_id) %> })
      </script>
      """
    end
  end

  def upgrade_link(assigns) do
    ~H"""
    <.button_link
      id="upgrade-link-2"
      href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
      mt?={false}
    >
      Upgrade
    </.button_link>
    """
  end

  defp change_plan_or_upgrade_text(nil), do: "Upgrade"

  defp change_plan_or_upgrade_text(%Subscription{status: Subscription.Status.deleted()}),
    do: "Upgrade"

  defp change_plan_or_upgrade_text(_subscription), do: "Change plan"

  def upgrade_call_to_action(assigns) do
    team = Plausible.Teams.with_subscription(assigns.current_team)

    upgrade_assistance_required? =
      case Plans.get_subscription_plan(team && team.subscription) do
        %Plan{kind: :business} -> true
        %EnterprisePlan{} -> true
        _ -> false
      end

    cond do
      not is_nil(assigns.current_role) and assigns.current_role not in [:owner, :billing] ->
        ~H"please reach out to the team owner to upgrade their subscription"

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
end
