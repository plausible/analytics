defmodule PlausibleWeb.Components.Billing do
  @moduledoc false

  use PlausibleWeb, :component
  use Plausible

  import PlausibleWeb.Components.Icons

  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.{Plan, Plans, EnterprisePlan, Subscription, Subscriptions}

  attr :site, Plausible.Site, required: false, default: nil
  attr :current_user, Plausible.Auth.User, required: true
  attr :current_team, :any, required: true
  attr :locked?, :boolean, required: true
  attr :link_class, :string, default: ""
  slot :inner_block, required: true

  def feature_gate(assigns) do
    ~H"""
    <div id="feature-gate-inner-block-container" class={if(@locked?, do: "pointer-events-none")}>
      {render_slot(@inner_block)}
    </div>
    <div
      :if={@locked?}
      id="feature-gate-overlay"
      class="absolute backdrop-blur-[8px] bg-white/70 dark:bg-gray-800/50 inset-0 flex justify-center items-center"
    >
      <div class="px-6 flex flex-col items-center gap-y-3">
        <div class="flex-shrink-0 bg-white dark:bg-gray-700 max-w-max rounded-md p-2 border border-gray-200 dark:border-gray-600 text-indigo-500">
          <Heroicons.lock_closed solid class="size-6 -mt-px pb-px" />
        </div>
        <div class="flex flex-col gap-y-1.5 items-center">
          <h3 class="font-medium text-gray-900 dark:text-gray-100">
            Upgrade to unlock
          </h3>
          <span
            id="lock-notice"
            class="max-w-sm sm:max-w-md mb-2 text-sm text-gray-600 dark:text-gray-100/60 leading-normal text-center"
          >
            To access this feature,
            <.upgrade_call_to_action
              current_user={@current_user}
              current_team={@current_team}
              link_class={@link_class}
            />
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :usage, :map, required: true
  attr :limit, :any, required: true
  attr :total_pageview_usage_domain, :string, default: nil

  def render_monthly_pageview_usage(%{usage: usage} = assigns)
      when is_map_key(usage, :last_30_days) do
    ~H"""
    <.monthly_pageview_usage_breakdown
      usage={@usage.last_30_days}
      limit={@limit}
      period={:last_30_days}
      expanded={Enum.count(@usage.last_30_days.per_site) <= 1}
      total_pageview_usage_domain={@total_pageview_usage_domain}
    />
    """
  end

  def render_monthly_pageview_usage(assigns) do
    exceeded =
      Plausible.Billing.Quota.exceeded_cycles(assigns.usage, assigns.limit, with_margin: false)

    show_all = :last_cycle in exceeded or :current_cycle in exceeded

    assigns = assign(assigns, :show_all, show_all)

    ~H"""
    <div id="monthly_pageview_usage_container" class="flex flex-col gap-12 pb-2">
      <.monthly_pageview_usage_breakdown
        usage={@usage.current_cycle}
        limit={@limit}
        period={:current_cycle}
        expanded={not @show_all and Enum.count(@usage.current_cycle.per_site) <= 1}
        total_pageview_usage_domain={@total_pageview_usage_domain}
      />
      <%= if @show_all do %>
        <.monthly_pageview_usage_breakdown
          usage={@usage.last_cycle}
          limit={@limit}
          period={:last_cycle}
          expanded={false}
          total_pageview_usage_domain={@total_pageview_usage_domain}
        />
        <.monthly_pageview_usage_breakdown
          usage={@usage.penultimate_cycle}
          limit={@limit}
          period={:penultimate_cycle}
          expanded={false}
          total_pageview_usage_domain={@total_pageview_usage_domain}
        />
      <% end %>
    </div>
    """
  end

  attr(:usage, :map, required: true)
  attr(:limit, :any, required: true)
  attr(:period, :atom, required: true)
  attr(:expanded, :boolean, required: true)
  attr(:total_pageview_usage_domain, :string, default: nil)

  defp monthly_pageview_usage_breakdown(assigns) do
    assigns =
      assign(
        assigns,
        :total_link,
        dashboard_url(
          assigns.total_pageview_usage_domain,
          assigns.usage.date_range
        )
      )

    ~H"""
    <div class="flex flex-col gap-3" x-data={"{ open: #{@expanded} }"}>
      <div class="flex flex-col gap-2">
        <p class="text-xs text-gray-600 dark:text-gray-400">
          {PlausibleWeb.TextHelpers.format_date_range(@usage.date_range)}
          <span :if={@period in [:current_cycle, :last_30_days]}>{cycle_label(@period)}</span>
        </p>
        <.usage_progress_bar
          :if={@limit != :unlimited}
          id={"total_pageviews_#{@period}"}
          usage={@usage.total}
          limit={@limit}
        />
      </div>
      <button
        class="flex justify-between items-center flex-wrap w-full text-left"
        x-on:click="open = !open"
      >
        <span class="flex items-center gap-1 text-sm font-medium text-gray-900 dark:text-gray-100">
          <Heroicons.chevron_right
            mini
            class="size-4 transition-transform"
            x-bind:class="open ? 'rotate-90' : ''"
          /> Total billable pageviews
          <.tooltip :if={@total_link} centered?={true}>
            <:tooltip_content>View billing period in dashboard</:tooltip_content>
            <.link
              href={@total_link}
              class="text-indigo-500 hover:text-indigo-600"
              data-test-id="total-pageviews-dashboard-link"
              x-on:click.stop
            >
              <.external_link_icon class="ml-0.5 size-3.5 [&_path]:stroke-2" />
            </.link>
          </.tooltip>
        </span>
        <span class="ml-5 text-sm font-medium text-gray-900 dark:text-gray-100">
          {PlausibleWeb.TextHelpers.number_format(@usage.total)}
          {if is_number(@limit), do: "/ #{PlausibleWeb.TextHelpers.number_format(@limit)}"}
        </span>
      </button>
      <div x-show="open" class="flex flex-col gap-3 text-sm text-gray-900 dark:text-gray-100">
        <.pageview_usage_row
          id={"pageviews_#{@period}"}
          label={if Enum.empty?(@usage.per_site), do: "Pageviews", else: "Total pageviews"}
          value={@usage.pageviews}
        />
        <.pageview_usage_row
          id={"custom_events_#{@period}"}
          label={if Enum.empty?(@usage.per_site), do: "Custom events", else: "Total custom events"}
          value={@usage.custom_events}
        />
        <div
          :if={not Enum.empty?(@usage.per_site)}
          id={"per_site_breakdown_#{@period}"}
          class="flex flex-col gap-3 border-t border-gray-200 dark:border-gray-700 pt-3 pl-5"
        >
          <div :for={{site, index} <- Enum.with_index(@usage.per_site)} class="flex flex-col gap-3">
            <hr :if={index > 0} class="border-gray-200 dark:border-gray-700" />
            <div class="flex justify-between flex-wrap font-medium">
              <span class="flex items-center gap-1 min-w-0">
                <span class="truncate">{site.domain}</span>
                <.tooltip centered?={true}>
                  <:tooltip_content>View billing period in dashboard</:tooltip_content>
                  <.link
                    href={dashboard_url(site.domain, @usage.date_range)}
                    class="shrink-0 text-indigo-500 hover:text-indigo-600"
                  >
                    <.external_link_icon class="ml-0.5 size-3.5 [&_path]:stroke-2" />
                  </.link>
                </.tooltip>
              </span>
              <span class="shrink-0">{PlausibleWeb.TextHelpers.number_format(site.total)}</span>
            </div>
            <.pageview_usage_row label="Pageviews" value={site.pageviews} />
            <.pageview_usage_row label="Custom events" value={site.custom_events} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, default: nil
  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp pageview_usage_row(assigns) do
    ~H"""
    <div id={@id} class="flex justify-between flex-wrap">
      <span class="flex items-center gap-1">
        <span class="inline-block size-4 text-center">•</span>
        {@label}
      </span>
      <span class="ml-5">{PlausibleWeb.TextHelpers.number_format(@value)}</span>
    </div>
    """
  end

  defp dashboard_url(nil, _date_range), do: nil

  defp dashboard_url(domain, date_range) do
    base = Routes.stats_path(PlausibleWeb.Endpoint, :stats, domain, [])

    base <>
      "?period=custom&from=#{Date.to_iso8601(date_range.first)}&to=#{Date.to_iso8601(date_range.last)}"
  end

  defp cycle_label(:current_cycle), do: "(current cycle)"
  defp cycle_label(:last_30_days), do: "(last 30 days)"

  @doc """
  Renders a color-coded progress bar based on usage percentage.

  Color scheme:
  - 0-90%: Green (healthy usage)
  - 91-99%: Gradient from green through yellow to orange (approaching limit)
  - 100%: Gradient from green through orange to red (at limit)
  """
  attr(:usage, :integer, required: true)
  attr(:limit, :any, required: true)
  attr(:rest, :global)

  def usage_progress_bar(assigns) do
    percentage = calculate_percentage(assigns.usage, assigns.limit)

    assigns =
      assigns
      |> assign(:percentage, percentage)
      |> assign(:color_class, progress_bar_color_from_percentage(percentage, assigns.limit))

    ~H"""
    <div class="w-full bg-gray-200 rounded-full h-1.5 dark:bg-gray-700" {@rest}>
      <div
        class={["h-1.5 rounded-full transition-all duration-300", @color_class]}
        style={"width: #{@percentage}%"}
      >
      </div>
    </div>
    """
  end

  defp calculate_percentage(_usage, :unlimited), do: 0
  defp calculate_percentage(_usage, 0), do: 0

  defp calculate_percentage(usage, limit) when is_number(limit) do
    percentage = usage / limit * 100
    min(percentage, 100.0) |> Float.round(1)
  end

  defp progress_bar_color_from_percentage(_percentage, :unlimited),
    do: "bg-green-500 dark:bg-green-600"

  defp progress_bar_color_from_percentage(_percentage, 0), do: "bg-gray-200 dark:bg-gray-700"

  defp progress_bar_color_from_percentage(percentage, _limit) when is_number(percentage) do
    cond do
      percentage >= 100.0 ->
        "bg-gradient-to-r from-green-500 via-orange-500 via-[80%] to-red-500 dark:from-green-600 dark:via-orange-600 dark:to-red-600"

      percentage >= 91 ->
        "bg-gradient-to-r from-green-500 via-yellow-500 via-[80%] to-orange-500 dark:from-green-600 dark:via-yellow-600 dark:to-orange-600"

      true ->
        "bg-green-500 dark:bg-green-600"
    end
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
        "text-sm w-full mt-6 block rounded-md py-2 px-3 text-center font-semibold leading-6 text-white transition-colors duration-150",
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

  attr :link_class, :string, default: ""
  attr :current_team, :any, required: true
  attr :current_user, :atom, required: true

  def upgrade_call_to_action(assigns) do
    user = assigns.current_user
    site = assigns[:site]
    team = Plausible.Teams.with_subscription(assigns.current_team)

    current_role =
      cond do
        not is_nil(site) ->
          case Plausible.Teams.Memberships.site_role(site, user) do
            {:ok, {_, site_role}} -> site_role
            _ -> nil
          end

        not is_nil(team) ->
          case Plausible.Teams.Memberships.team_role(team, user) do
            {:ok, team_role} -> team_role
            _ -> nil
          end

        true ->
          nil
      end

    upgrade_assistance_required? =
      case Plans.get_subscription_plan(team && team.subscription) do
        %Plan{kind: :business} -> true
        %EnterprisePlan{} -> true
        _ -> false
      end

    cond do
      not is_nil(current_role) and current_role not in [:owner, :billing] ->
        ~H"ask your team owner to upgrade their subscription."

      upgrade_assistance_required? ->
        ~H"""
        contact
        <.styled_link href="mailto:hello@plausible.io" class={"font-medium " <> @link_class}>
          hello@plausible.io
        </.styled_link>
        to upgrade your subscription.
        """

      true ->
        ~H"""
        <.styled_link
          class={"inline-block font-medium " <> @link_class}
          href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
        >
          upgrade your subscription.
        </.styled_link>
        """
    end
  end

  def present_plan_name(%Plausible.Billing.Plan{kind: kind}),
    do: kind |> to_string() |> String.capitalize()

  def present_plan_name(%Plausible.Billing.EnterprisePlan{}), do: "Enterprise"
  def present_plan_name(:free_10k), do: "Free"
  def present_plan_name(_), do: "Plan"

  def present_subscription_interval(subscription) do
    case Plans.subscription_interval(subscription) do
      "monthly" -> "month"
      "yearly" -> "year"
      interval -> interval
    end
  end

  @spec present_subscription_status(Subscription.Status.status()) :: String.t()
  def present_subscription_status(Subscription.Status.active()), do: "Active"
  def present_subscription_status(Subscription.Status.past_due()), do: "Past due"
  def present_subscription_status(Subscription.Status.deleted()), do: "Cancelled"
  def present_subscription_status(Subscription.Status.paused()), do: "Paused"
  def present_subscription_status(status), do: status

  def subscription_pill_color(Subscription.Status.active()), do: :green
  def subscription_pill_color(Subscription.Status.past_due()), do: :yellow
  def subscription_pill_color(Subscription.Status.paused()), do: :red
  def subscription_pill_color(Subscription.Status.deleted()), do: :red
  def subscription_pill_color(_), do: :gray

  def trial_button_label(team) do
    if Plausible.Teams.Billing.enterprise_configured?(team) do
      "Upgrade"
    else
      "Choose a plan →"
    end
  end

  def change_plan_button_label(nil), do: "Upgrade"

  def change_plan_button_label(subscription) do
    if Subscriptions.resumable?(subscription) && subscription.cancel_url do
      "Change plan"
    else
      "Upgrade"
    end
  end

  def format_invoices(invoice_list) do
    Enum.map(invoice_list, fn invoice ->
      %{
        date: invoice["payout_date"] |> Date.from_iso8601!() |> Calendar.strftime("%b %-d, %Y"),
        amount: (invoice["amount"] / 1) |> :erlang.float_to_binary(decimals: 2),
        currency: invoice["currency"] |> PlausibleWeb.BillingView.present_currency(),
        url: invoice["receipt_url"]
      }
    end)
  end
end
