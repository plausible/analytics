defmodule PlausibleWeb.Live.SubscriptionSettings do
  @moduledoc """
  LiveView for the subscription settings page.
  """
  use PlausibleWeb, :live_view
  use Plausible

  import PlausibleWeb.Components.Billing.Helpers

  alias Plausible.Teams
  alias PlausibleWeb.Router.Helpers, as: Routes

  def mount(_params, _session, socket) do
    team = socket.assigns.current_team
    subscription = Teams.Billing.get_subscription(team)
    invoices = Plausible.Billing.paddle_api().get_invoices(subscription)
    pageview_usage = Teams.Billing.monthly_pageview_usage(team)
    site_usage = Teams.Billing.site_usage(team)
    team_member_usage = Teams.Billing.team_member_usage(team)

    usage = %{
      monthly_pageviews: pageview_usage,
      sites: site_usage,
      team_members: team_member_usage
    }

    notification_type = Plausible.Billing.Quota.usage_notification_type(team, usage)

    total_pageview_usage_domain =
      if site_usage == 1 do
        [site] = Plausible.Teams.owned_sites(team)
        site.domain
      else
        on_ee(do: team && consolidated_view_domain(team), else: nil)
      end

    socket =
      socket
      |> assign(:subscription, subscription)
      |> assign(:invoices, invoices)
      |> assign(:pageview_limit, Teams.Billing.monthly_pageview_limit(subscription))
      |> assign(:pageview_usage, pageview_usage)
      |> assign(:site_usage, site_usage)
      |> assign(:site_limit, Teams.Billing.site_limit(team))
      |> assign(:team_member_limit, Teams.Billing.team_member_limit(team))
      |> assign(:team_member_usage, team_member_usage)
      |> assign(:notification_type, notification_type)
      |> assign(:total_pageview_usage_domain, total_pageview_usage_domain)
      |> assign(:current_path, "/settings/billing/subscription")

    {:ok, socket, layout: {PlausibleWeb.LayoutView, :settings}}
  end

  def render(assigns) do
    ~H"""
    <.settings_tiles>
      <%= if is_nil(@current_team) || Plausible.Teams.on_trial?(@current_team) do %>
        <.tile docs="trial-to-paid">
          <:title>Current plan</:title>
          <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
            <div class="flex flex-col gap-1">
              <div class="flex items-center gap-2">
                <span class="text-sm font-semibold dark:text-gray-100">Free trial</span>
                <.pill :if={@current_team} color={:yellow}>
                  {Plausible.Teams.trial_days_left(@current_team)} days left
                </.pill>
              </div>
              <p
                :if={is_nil(@current_team)}
                class="text-sm text-gray-600 dark:text-gray-400"
              >
                Your 30-day trial will start when you add your first site
              </p>
            </div>
            <.button_link
              href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
              mt?={false}
              id="upgrade-or-change-plan-link"
            >
              {trial_button_label(@current_team)}
            </.button_link>
          </div>
        </.tile>
      <% else %>
        <.tile docs="billing">
          <:title>Current plan</:title>
          <%= if @subscription do %>
            <div class="flex flex-col gap-5">
              <PlausibleWeb.Components.Billing.Notice.subscription_cancelled
                subscription={@subscription}
                dismissable={false}
              />
              <div class="flex flex-col sm:flex-row justify-between items-start gap-4">
                <div class="flex flex-col gap-1">
                  <div class="flex items-center gap-2 flex-wrap">
                    <span class="text-sm font-semibold dark:text-gray-100">
                      {present_plan_name(Plausible.Billing.Plans.get_subscription_plan(@subscription))}
                    </span>
                    <.pill color={subscription_pill_color(@subscription.status)}>
                      {present_subscription_status(@subscription.status)}
                    </.pill>
                  </div>
                  <p class="text-sm text-gray-600 dark:text-gray-400">
                    Up to {PlausibleWeb.AuthView.subscription_quota(@subscription)} monthly pageviews
                  </p>
                  <%= if @subscription.next_bill_amount && @subscription.next_bill_date do %>
                    <p class="text-sm text-gray-600 dark:text-gray-400">
                      {PlausibleWeb.BillingView.present_currency(@subscription.currency_code)}{@subscription.next_bill_amount} / {present_subscription_interval(
                        @subscription
                      )} • Renews on {Calendar.strftime(@subscription.next_bill_date, "%b %-d, %Y")}
                    </p>
                  <% end %>
                </div>
                <div class="flex gap-2">
                  <.button_link
                    :if={
                      @subscription &&
                        Plausible.Billing.Subscriptions.resumable?(@subscription) &&
                        @subscription.update_url
                    }
                    theme="secondary"
                    href={@subscription.update_url}
                    mt?={false}
                    id="billing-details-link"
                  >
                    Billing details
                  </.button_link>
                  <.button_link
                    :if={
                      not (Plausible.Teams.Billing.enterprise_configured?(@current_team) &&
                             Plausible.Billing.Subscriptions.halted?(@subscription))
                    }
                    href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
                    mt?={false}
                    id="upgrade-or-change-plan-link"
                  >
                    {change_plan_button_label(@subscription)}
                  </.button_link>
                </div>
              </div>
            </div>
          <% else %>
            <PlausibleWeb.Components.Billing.Notice.usage_notification
              type={:trial_ended}
              team={@current_team}
            />
          <% end %>
        </.tile>
      <% end %>

      <.tile docs="subscription-plans">
        <:title>
          <a id="subscription">Monthly usage</a>
        </:title>

        <div class="flex flex-col gap-12">
          <PlausibleWeb.Components.Billing.Notice.usage_notification
            :if={
              @notification_type in [
                :pageview_approaching_limit,
                :traffic_exceeded_current_cycle,
                :traffic_exceeded_last_cycle,
                :traffic_exceeded_sustained,
                :grace_period_active,
                :manual_lock_grace_period_active,
                :dashboard_locked
              ]
            }
            type={@notification_type}
            team={@current_team}
          />
          <PlausibleWeb.Components.Billing.render_monthly_pageview_usage
            usage={@pageview_usage}
            limit={@pageview_limit}
            total_pageview_usage_domain={@total_pageview_usage_domain}
          />
        </div>
      </.tile>

      <.tile docs="subscription-plans">
        <:title>Site and team usage</:title>

        <div class="flex flex-col gap-8">
          <PlausibleWeb.Components.Billing.Notice.usage_notification
            :if={
              @notification_type in [
                :site_limit_reached,
                :team_member_limit_reached,
                :site_and_team_member_limit_reached
              ]
            }
            type={@notification_type}
            team={@current_team}
          />
          <div class="grid grid-cols-2 gap-8">
            <div class="flex flex-col gap-3">
              <PlausibleWeb.Components.Billing.usage_progress_bar
                id="site-usage-row"
                usage={@site_usage}
                limit={@site_limit}
              />
              <div class="flex justify-between flex-wrap text-sm font-medium text-gray-900 dark:text-gray-100">
                <span>Owned sites</span>
                <span data-test-id="sites-usage">
                  {PlausibleWeb.TextHelpers.number_format(@site_usage)}
                  {if is_number(@site_limit),
                    do: "/ #{PlausibleWeb.TextHelpers.number_format(@site_limit)}"}
                  {if @site_limit == :unlimited, do: "/ Unlimited"}
                </span>
              </div>
            </div>
            <div class="flex flex-col gap-3">
              <PlausibleWeb.Components.Billing.usage_progress_bar
                id="team-member-usage-row"
                usage={@team_member_usage}
                limit={@team_member_limit}
              />
              <div class="flex justify-between flex-wrap text-sm font-medium text-gray-900 dark:text-gray-100">
                <span>Team members</span>
                <span data-test-id="team-member-usage">
                  {PlausibleWeb.TextHelpers.number_format(@team_member_usage)}
                  {if is_number(@team_member_limit),
                    do: "/ #{PlausibleWeb.TextHelpers.number_format(@team_member_limit)}"}
                  {if @team_member_limit == :unlimited, do: "/ Unlimited"}
                </span>
              </div>
            </div>
          </div>
        </div>
      </.tile>

      <.tile :if={@subscription} docs="download-invoices">
        <:title>
          <a id="invoices">Invoices</a>
        </:title>
        <%= case @invoices do %>
          <% {:error, :no_invoices} -> %>
            <p class="mt-10 mb-12 text-center text-sm text-gray-600 dark:text-gray-400">
              You don't have any invoices yet.
            </p>
          <% {:error, :request_failed} -> %>
            <.notice theme={:gray} title="We couldn't retrieve your invoices">
              Please refresh the page or try again later
            </.notice>
          <% {:ok, invoice_list} when is_list(invoice_list) -> %>
            <div x-data="{showAll: false}" x-cloak>
              <.table
                rows={Enum.with_index(format_invoices(invoice_list))}
                row_attrs={
                  fn {_invoice, idx} ->
                    %{
                      "x-show" => "showAll || #{idx} < 3"
                    }
                  end
                }
              >
                <:tbody :let={{invoice, _idx}}>
                  <.td>{invoice.date}</.td>
                  <.td>{invoice.currency <> invoice.amount}</.td>
                  <.td class="flex justify-end">
                    <.styled_link href={invoice.url} new_tab={true}></.styled_link>
                  </.td>
                </:tbody>
                <tr :if={length(invoice_list) > 3}>
                  <td colspan="3">
                    <.button
                      theme="secondary"
                      x-on:click="showAll = true"
                      x-show="!showAll"
                    >
                      Show more
                    </.button>
                  </td>
                </tr>
              </.table>
            </div>
        <% end %>
      </.tile>
    </.settings_tiles>

    <%= if Plausible.Billing.Subscriptions.resumable?(@subscription) && @subscription.cancel_url do %>
      <div class="flex gap-2">
        <.button_link theme="danger" href={@subscription.cancel_url} mt?={false}>
          Cancel plan
        </.button_link>
        <%= if Application.get_env(:plausible, :environment) == "dev" do %>
          <.button_link
            href={@subscription.update_url}
            theme="secondary"
            class="text-yellow-600 dark:text-yellow-400"
            mt?={false}
          >
            [DEV ONLY] Change status
          </.button_link>
        <% end %>
      </div>
    <% end %>
    """
  end

  on_ee do
    defp consolidated_view_domain(team) do
      view = Plausible.ConsolidatedView.get(team)

      if not is_nil(view) and Plausible.ConsolidatedView.ok_to_display?(team) do
        view.domain
      end
    end
  end
end
