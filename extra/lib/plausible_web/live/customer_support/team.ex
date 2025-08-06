defmodule PlausibleWeb.Live.CustomerSupport.Team do
  @moduledoc """
  Team coordinator LiveView for Customer Support interface.

  Manages tab-based navigation and delegates rendering to specialized 
  components: Overview, Members, Sites, Billing, SSO, and Audit.
  """
  use PlausibleWeb.CustomerSupport.Live

  alias PlausibleWeb.CustomerSupport.Team.Components.{
    Overview,
    Members,
    Sites,
    Billing,
    SSO,
    Audit
  }

  require Plausible.Billing.Subscription.Status

  def handle_params(%{"id" => id} = params, _uri, socket) do
    tab = params["tab"] || "overview"
    team_id = String.to_integer(id)
    team = Resource.Team.get(team_id)

    if team do
      socket =
        socket
        |> assign(:team, team)
        |> assign(:tab, tab)

      {:noreply, go_to_tab(socket, tab, params, :team, tab_component(tab))}
    else
      {:noreply, redirect(socket, to: Routes.customer_support_path(socket, :index))}
    end
  end

  def handle_event("unlock", _, socket) do
    {:noreply, unlock_team(socket)}
  end

  def handle_event("lock", _, socket) do
    {:noreply, lock_team(socket)}
  end

  def handle_event("refund-lock", _, socket) do
    team = socket.assigns.team

    {:ok, team} =
      Plausible.Repo.transaction(fn ->
        yesterday = Date.shift(Date.utc_today(), day: -1)
        Plausible.Billing.SiteLocker.set_lock_status_for(team, true)

        Plausible.Repo.update!(
          Plausible.Billing.Subscription.changeset(team.subscription, %{next_bill_date: yesterday})
        )

        Resource.Team.get(team.id)
      end)

    {:noreply, assign(socket, team: team)}
  end

  def render(assigns) do
    ~H"""
    <Layout.layout show_search={false} flash={@flash}>
      <.team_header team={@team} />
      <.team_tab_navigation team={@team} tab={@tab} />
      <.team_stats team={@team} />

      <.live_component
        module={tab_component(@tab)}
        team={@team}
        tab={@tab}
        id={"team-#{@team.id}-#{@tab}"}
      />
    </Layout.layout>
    """
  end

  defp team_header(assigns) do
    ~H"""
    <div>
      <div class="sm:flex sm:items-center sm:justify-between">
        <div class="sm:flex sm:space-x-5">
          <div class="shrink-0">
            <div class={[
              team_bg(@team.identifier),
              "rounded-full p-1 flex items-center justify-center"
            ]}>
              <Heroicons.user_group class="h-14 w-14 text-white dark:text-gray-300" />
            </div>
          </div>
          <div class="mt-4 text-center sm:mt-0 sm:pt-1 sm:text-left">
            <p class="text-xl font-bold dark:text-gray-300 text-gray-900 sm:text-2xl">
              {@team.name}
            </p>
            <p class="text-sm font-medium dark:text-gray-500">
              <span :if={@team.setup_complete}>Set up at {@team.setup_at}</span>
              <span :if={!@team.setup_complete}>Not set up yet</span>
            </p>
          </div>
        </div>

        <div class="mt-5 flex justify-center sm:mt-0">
          <.input_with_clipboard
            id="team-identifier"
            name="team-identifier"
            label="Team Identifier"
            value={@team.identifier}
            onfocus="this.value = this.value;"
          />
        </div>
      </div>
    </div>
    """
  end

  defp team_tab_navigation(assigns) do
    ~H"""
    <.tab_navigation tab={@tab}>
      <:tabs>
        <.tab to="overview" tab={@tab}>Overview</.tab>
        <.tab to="members" tab={@tab}>Members</.tab>
        <.tab to="sites" tab={@tab}>Sites</.tab>
        <.tab :if={has_sso_integration?(@team)} to="sso" tab={@tab}>SSO</.tab>
        <.tab to="billing" tab={@tab}>Billing</.tab>
        <.tab to="audit" tab={@tab}>Audit</.tab>
      </:tabs>
    </.tab_navigation>
    """
  end

  defp team_stats(assigns) do
    team = assigns.team
    usage = Plausible.Teams.Billing.quota_usage(team, with_features: true)

    limits = %{
      monthly_pageviews: Plausible.Teams.Billing.monthly_pageview_limit(team),
      sites: Plausible.Teams.Billing.site_limit(team),
      team_members: Plausible.Teams.Billing.team_member_limit(team)
    }

    assigns = assign(assigns, usage: usage, limits: limits)

    ~H"""
    <div class="grid grid-cols-1 divide-y border-t sm:grid-cols-3 sm:divide-x sm:divide-y-0 dark:bg-gray-850 text-gray-900 dark:text-gray-400 dark:divide-gray-800 dark:border-gray-600">
      <div class="px-6 py-5 text-center text-sm font-medium">
        <span>
          <strong>Subscription status</strong> <br />{subscription_status(@team)}
          <div :if={
            @team.subscription &&
              @team.subscription.status == Plausible.Billing.Subscription.Status.deleted() &&
              !@team.grace_period
          }>
            <span class="flex items-center gap-x-8 justify-center mt-1">
              <div :if={not Plausible.Teams.locked?(@team)}>
                <Heroicons.lock_open solid class="inline stroke-2 w-4 h-4 text-red-400 mr-1" />
                <.styled_link
                  phx-click="refund-lock"
                  data-confirm="Are you sure you want to lock? The only way to unlock, is for the user to resubscribe."
                >
                  Refund Lock
                </.styled_link>
              </div>

              <div :if={Plausible.Teams.locked?(@team)}>
                <Heroicons.lock_closed solid class="inline stroke-2 w-4 h-4 text-red-400 mr-1" />
                Locked
              </div>
            </span>
          </div>
        </span>
      </div>
      <div class="px-6 py-5 text-center text-sm font-medium">
        <span>
          <strong>Subscription plan</strong> <br />{subscription_plan(@team)}
        </span>
      </div>
      <div class="px-6 py-5 text-center text-sm font-medium">
        <span>
          <strong>Grace Period</strong> <br />{grace_period_status(@team)}

          <div :if={@team.grace_period}>
            <span class="flex items-center gap-x-8 justify-center mt-1">
              <div>
                <Heroicons.lock_open solid class="inline stroke-2 w-4 h-4 text-red-400 mr-1" />
                <.styled_link phx-click="unlock">Unlock</.styled_link>
              </div>

              <div>
                <Heroicons.lock_closed solid class="inline stroke-2 w-4 h-4 text-red-400 mr-1" />
                <.styled_link phx-click="lock">Lock</.styled_link>
              </div>
            </span>
          </div>
        </span>
      </div>
    </div>
    """
  end

  defp tab_component("overview"), do: Overview
  defp tab_component("members"), do: Members
  defp tab_component("sites"), do: Sites
  defp tab_component("billing"), do: Billing
  defp tab_component("sso"), do: SSO
  defp tab_component("audit"), do: Audit
  defp tab_component(_), do: Overview

  defp has_sso_integration?(team) do
    case Plausible.Auth.SSO.get_integration_for(team) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  defp team_bg(term) do
    list = [
      "bg-blue-500",
      "bg-blue-600",
      "bg-blue-700",
      "bg-blue-800",
      "bg-cyan-500",
      "bg-cyan-600",
      "bg-cyan-700",
      "bg-cyan-800",
      "bg-red-500",
      "bg-red-600",
      "bg-red-700",
      "bg-red-800",
      "bg-green-500",
      "bg-green-600",
      "bg-green-700",
      "bg-green-800",
      "bg-yellow-500",
      "bg-yellow-600",
      "bg-yellow-700",
      "bg-yellow-800",
      "bg-orange-500",
      "bg-orange-600",
      "bg-orange-700",
      "bg-orange-800",
      "bg-purple-500",
      "bg-purple-600",
      "bg-purple-700",
      "bg-purple-800",
      "bg-gray-500",
      "bg-gray-600",
      "bg-gray-700",
      "bg-gray-800",
      "bg-emerald-500",
      "bg-emerald-600",
      "bg-emerald-700",
      "bg-emerald-800"
    ]

    idx = :erlang.phash2(term, length(list))
    Enum.at(list, idx)
  end

  defp subscription_status(team) do
    cond do
      team && team.subscription ->
        status_str =
          PlausibleWeb.SettingsView.present_subscription_status(team.subscription.status)

        if team.subscription.paddle_subscription_id do
          assigns = %{status_str: status_str, subscription: team.subscription}

          ~H"""
          <.styled_link new_tab={true} href={manage_url(@subscription)}>{@status_str}</.styled_link>
          """
        else
          status_str
        end

      Plausible.Teams.on_trial?(team) ->
        "On trial"

      true ->
        "Trial expired"
    end
  end

  defp manage_url(%{paddle_subscription_id: paddle_id} = _subscription) do
    Plausible.Billing.PaddleApi.vendors_domain() <>
      "/subscriptions/customers/manage/" <> paddle_id
  end

  defp subscription_plan(team) do
    subscription = team.subscription

    if Plausible.Billing.Subscription.Status.active?(subscription) &&
         subscription.paddle_subscription_id do
      quota = PlausibleWeb.AuthView.subscription_quota(subscription)
      interval = PlausibleWeb.AuthView.subscription_interval(subscription)

      assigns = %{quota: quota, interval: interval, subscription: subscription}

      ~H"""
      <.styled_link new_tab={true} href={manage_url(@subscription)}>
        {@quota} ({@interval})
      </.styled_link>
      """
    else
      "--"
    end
  end

  defp grace_period_status(team) do
    grace_period = team.grace_period

    case grace_period do
      nil ->
        "--"

      %{manual_lock: true, is_over: true} ->
        "Manually locked"

      %{manual_lock: true, is_over: false} ->
        "Waiting for manual lock"

      %{is_over: true} ->
        "ended"

      %{end_date: %Date{} = end_date} ->
        days_left = Date.diff(end_date, Date.utc_today())
        "#{days_left} days left"
    end
  end

  defp lock_team(socket) do
    if socket.assigns.team.grace_period do
      team = Plausible.Teams.end_grace_period(socket.assigns.team)
      Plausible.Billing.SiteLocker.set_lock_status_for(team, true)

      put_live_flash(socket, :success, "Team locked. Grace period ended.")
      assign(socket, team: team)
    else
      put_live_flash(socket, :error, "No grace period")
      socket
    end
  end

  defp unlock_team(socket) do
    if socket.assigns.team.grace_period do
      team = Plausible.Teams.remove_grace_period(socket.assigns.team)
      Plausible.Billing.SiteLocker.set_lock_status_for(team, false)

      put_live_flash(socket, :success, "Team unlocked. Grace period removed.")
      assign(socket, team: team)
    else
      socket
    end
  end
end
