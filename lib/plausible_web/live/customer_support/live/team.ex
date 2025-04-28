defmodule PlausibleWeb.CustomerSupport.Live.Team do
  use Plausible.CustomerSupport.Resource, :component

  alias Plausible.Billing.Subscription
  alias Plausible.Teams
  alias Plausible.Teams.Management.Layout

  alias PlausibleWeb.Router.Helpers, as: Routes

  def update(assigns, socket) do
    team = Resource.Team.get(assigns.resource_id)
    changeset = Plausible.Teams.Team.crm_changeset(team, %{})
    form = to_form(changeset)

    usage = Teams.Billing.quota_usage(team, with_features: true)

    limits = %{
      monthly_pageviews: Teams.Billing.monthly_pageview_limit(team),
      sites: Teams.Billing.site_limit(team),
      team_members: Teams.Billing.team_member_limit(team)
    }

    {:ok,
     assign(socket,
       team: team,
       form: form,
       tab: "overview",
       usage: usage,
       limits: limits
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="overflow-hidden rounded-lg bg-white">
        <h2 class="sr-only" id="profile-overview-title">Profile Overview</h2>
        <div class="bg-white p-6">
          <div class="sm:flex sm:items-center sm:justify-between">
            <div class="sm:flex sm:space-x-5">
              <div class="shrink-0">
                <div class={[
                  team_bg(@team.identifier),
                  "rounded-full p-1 flex items-center justify-center"
                ]}>
                  <Heroicons.user_group class="h-14 w-14 text-white" />
                </div>
              </div>
              <div class="mt-4 text-center sm:mt-0 sm:pt-1 sm:text-left">
                <p class="text-xl font-bold text-gray-900 sm:text-2xl">
                  {@team.name}
                </p>
                <p class="text-sm font-medium text-gray-600">
                  <span :if={@team.setup_complete}>Set up at {@team.setup_at}</span>
                  <span :if={!@team.setup_complete}>Not set up yet</span>
                </p>
              </div>
            </div>
            <div :if={@team.grace_period}>
              <span :if={@team.locked} class="flex items-center">
                <Heroicons.lock_closed solid class="inline stroke-2 w-4 h-4 text-red-400 mr-2" />
                <.styled_link phx-click="unlock" phx-target={@myself}>Unlock Team</.styled_link>
              </span>

              <span :if={!@team.locked} class="flex items-center">
                <Heroicons.lock_open class="inline stroke-2 w-4 h-4 text-gray-800 mr-2" />
                <.styled_link phx-click="lock" phx-target={@myself}>Lock Team</.styled_link>
              </span>
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

        <div>
          <div class="grid grid-cols-1 sm:hidden">
            <!-- Use an "onChange" listener to redirect the user to the selected tab URL. -->
            <select
              aria-label="Select a tab"
              class="col-start-1 row-start-1 w-full appearance-none rounded-md bg-white py-2 pl-3 pr-8 text-base text-gray-900 outline outline-1 -outline-offset-1 outline-gray-300 focus:outline focus:outline-2 focus:-outline-offset-2 focus:outline-indigo-600"
            >
              <option>Overview</option>
              <option>Sites</option>
              <option selected>Members</option>
              <option>Billing</option>
            </select>
          </div>
          <div class="hidden sm:block">
            <nav class="isolate flex divide-x divide-gray-200 rounded-lg shadow" aria-label="Tabs">
              <.tab to="overview" target={@myself} tab={@tab}>Overview</.tab>
              <.tab to="members" target={@myself} tab={@tab}>
                Members ({@usage.team_members}/{@limits.team_members})
              </.tab>
              <.tab to="sites" target={@myself} tab={@tab}>
                Sites ({@usage.sites}/{@limits.sites})
              </.tab>
            </nav>
          </div>
        </div>

        <div class="grid grid-cols-1 divide-y divide-gray-200 border-t border-gray-200 bg-gray-50 sm:grid-cols-3 sm:divide-x sm:divide-y-0">
          <div class="px-6 py-5 text-center text-sm font-medium">
            <span class="text-gray-900">
              <strong>Subscription status</strong> <br />{subscription_status(@team)}
            </span>
          </div>
          <div class="px-6 py-5 text-center text-sm font-medium">
            <span class="text-gray-900">
              <strong>Subscription plan</strong> <br />{subscription_plan(@team)}
            </span>
          </div>
          <div class="px-6 py-5 text-center text-sm font-medium">
            <span class="text-gray-900">
              <span class="text-gray-900">
                <strong>Grace Period</strong> <br />{grace_period_status(@team)}
              </span>
            </span>
          </div>
        </div>

        <div :if={@tab == "overview"} class="mt-2 m-4">
          <div class="bg-gray-100 p-4 rounded-md mt-8 mb-8">
            <span class="text-gray-900">
              <span class="text-gray-900">
                <strong>Usage</strong> <br />
                <ul>
                  <li :for={
                    {cycle, date, total, limit} <-
                      monthly_pageviews_usage(@usage.monthly_pageviews, @limits.monthly_pageviews)
                  }>
                    {cycle} ({date}): {total} / {limit}
                  </li>
                </ul>
              </span>
            </span>
          </div>
          <.form :let={f} for={@form} phx-submit="change" phx-target={@myself}>
            <.input field={f[:trial_expiry_date]} label="Trial Expiry Date" />
            <.input field={f[:accept_traffic_until]} label="Accept  traffic Until" />
            <.input
              type="checkbox"
              field={f[:allow_next_upgrade_override] |> IO.inspect(label: :f)}
              label="Allow Next Upgrade Override"
            />

            <.input type="textarea" field={f[:notes]} label="Notes" />
            <.button type="submit">
              Save
            </.button>
          </.form>
        </div>

        <div :if={@tab == "sites"} class="mt-2 m-4">
          <.table rows={@sites.entries}>
            <:thead>
              <.th>Domain</.th>
              <.th>Timezone</.th>
              <.th invisible>Dashboard</.th>
            </:thead>
            <:tbody :let={site}>
              <.td>
                <div class="flex items-center">
                  <img
                    src="/favicon/sources/{site.domain}"
                    onerror="this.onerror=null; this.src='/favicon/sources/placeholder';"
                    class="w-4 h-4 flex-shrink-0 mt-px mr-2"
                  />
                  <.styled_link
                    phx-click="open"
                    phx-value-id={site.id}
                    phx-value-type="site"
                    class="cursor-pointer flex block items-center"
                  >
                    {site.domain}
                  </.styled_link>
                </div>
              </.td>
              <.td>{site.domain_changed_from}</.td>
              <.td>{site.timezone}</.td>
              <.td>
                <.styled_link
                  new_tab={true}
                  href={Routes.stats_path(PlausibleWeb.Endpoint, :stats, site.domain, [])}
                >
                  Go to dashboard
                </.styled_link>
              </.td>
            </:tbody>
          </.table>
        </div>

        <div :if={@tab == "members"} class="mt-2 m-4">
          <.table rows={Layout.sorted_for_display(@layout)}>
            <:thead>
              <.th>User</.th>
              <.th>Type</.th>
              <.th>Role</.th>
            </:thead>
            <:tbody :let={{_, member}}>
              <.td>
                <div :if={member.id != 0}>
                  <.styled_link
                    phx-click="open"
                    phx-value-id={member.id}
                    phx-value-type="user"
                    class="cursor-pointer flex block items-center"
                  >
                    <img
                      src={
                        Plausible.Auth.User.profile_img_url(%Plausible.Auth.User{email: member.email})
                      }
                      class="mr-4 w-6 rounded-full bg-gray-300"
                    />
                    {member.name} &lt;{member.email}&gt;
                  </.styled_link>
                </div>
                <div :if={member.id == 0} class="flex items-center">
                  <img
                    src={
                      Plausible.Auth.User.profile_img_url(%Plausible.Auth.User{email: member.email})
                    }
                    class="mr-4 w-6 rounded-full bg-gray-300"
                  />
                  {member.name} &lt;{member.email}&gt;
                </div>
              </.td>
              <.td>
                {member.type}
              </.td>
              <.td>
                {member.role}
              </.td>
            </:tbody>
          </.table>
        </div>
      </div>
    </div>
    """
  end

  def render_result(assigns) do
    ~H"""
    <div class="flex-1 -mt-px w-full">
      <div class="w-full flex items-center justify-between space-x-4">
        <div class={[
          team_bg(@resource.object.identifier),
          "rounded-full p-1 flex items-center justify-center"
        ]}>
          <Heroicons.user_group class="h-4 w-4 text-white" />
        </div>
        <h3
          class="text-gray-900 font-medium text-lg truncate dark:text-gray-100"
          style="width: calc(100% - 4rem)"
        >
          {@resource.object.name}
        </h3>

        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
          Team
        </span>
      </div>

      <hr class="mt-4 mb-4 flex-grow border-t border-gray-200 dark:border-gray-600" />
      <div class="text-sm">
        Team identifier:
        <code class="font-mono">{@resource.object.identifier |> String.slice(0, 8)}</code>
        <br />
        Owned by: {@resource.object.owners
        |> Enum.map(& &1.name)
        |> Enum.join(", ")}
      </div>
    </div>
    """
  end

  def handle_event("change", %{"team" => params}, socket) do
    changeset = Plausible.Teams.Team.crm_changeset(socket.assigns.team, params)

    case Plausible.Repo.update(changeset) do
      {:ok, team} ->
        success(socket, "Team saved")
        {:noreply, assign(socket, team: team, form: to_form(changeset))}

      {:error, changeset} ->
        failure(socket, "Error saving team: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("unlock", _, socket) do
    {:noreply, unlock_team(socket)}
  end

  def handle_event("lock", _, socket) do
    {:noreply, lock_team(socket)}
  end

  def handle_event("switch", %{"to" => "overview"}, socket) do
    {:noreply, assign(socket, tab: "overview")}
  end

  def handle_event("switch", %{"to" => "members"}, socket) do
    layout = Layout.init(socket.assigns.team)
    {:noreply, assign(socket, tab: "members", layout: layout)}
  end

  def handle_event("switch", %{"to" => "sites"}, socket) do
    any_owner = Plausible.Repo.preload(socket.assigns.team, [:owners]).owners |> hd()
    sites = Teams.Sites.list(any_owner, %{}, team: socket.assigns.team)

    {:noreply, assign(socket, tab: "sites", sites: sites)}
  end

  def team_bg(term) do
    list = [
      "bg-blue-500",
      "bg-blue-600",
      "bg-blue-700",
      "bg-blue-800",
      "bg-indigo-500",
      "bg-indigo-600",
      "bg-indigo-700",
      "bg-indigo-800",
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

  def subscription_status(team) do
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

  def subscription_plan(team) do
    subscription = team.subscription

    if Subscription.Status.active?(subscription) && subscription.paddle_subscription_id do
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

  def grace_period_status(team) do
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

  attr :to, :string, required: true
  attr :tab, :string, required: true
  attr :target, :any, required: true
  slot :inner_block, required: true

  defp tab(assigns) do
    ~H"""
    <a
      phx-click="switch"
      phx-value-to={@to}
      phx-target={@target}
      class="group relative min-w-0 flex-1 overflow-hidden rounded-l-lg bg-white px-4 py-4 text-center text-sm font-medium text-gray-500 hover:bg-gray-50 hover:text-gray-700 focus:z-10 cursor-pointer"
    >
      <span class={if(@tab == @to, do: "font-bold text-gray-800")}>
        {render_slot(@inner_block)}
      </span>
      <span
        aria-hidden="true"
        class={[
          "absolute inset-x-0 bottom-0 h-0.5",
          if(@tab == @to, do: "bg-indigo-500", else: "bg-transparent")
        ]}
      >
      </span>
    </a>
    """
  end

  defp lock_team(socket) do
    if socket.assigns.team.grace_period do
      team =
        socket.assigns.team
        |> Plausible.Billing.SiteLocker.set_lock_status_for(true)
        |> Plausible.Teams.end_grace_period()

      success(socket, "Team locked. Grace period ended.")
      assign(socket, team: team)
    else
      failure(socket, "No grace period")
      socket
    end
  end

  defp unlock_team(socket) do
    if socket.assigns.team.grace_period do
      team =
        socket.assigns.team
        |> Plausible.Teams.remove_grace_period()
        |> Plausible.Billing.SiteLocker.set_lock_status_for(false)

      success(socket, "Team unlocked. Grace period removed.")
      assign(socket, team: team)
    else
      socket
    end
  end

  defp monthly_pageviews_usage(usage, limit) do
    usage
    |> Enum.sort_by(fn {_cycle, usage} -> usage.date_range.first end, :desc)
    |> Enum.map(fn {cycle, usage} ->
      {cycle, PlausibleWeb.TextHelpers.format_date_range(usage.date_range), usage.total, limit}
    end)
  end
end
