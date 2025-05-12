defmodule PlausibleWeb.CustomerSupport.Live.Team do
  use Plausible.CustomerSupport.Resource, :component

  alias Plausible.Billing.Subscription
  alias Plausible.Teams
  alias Plausible.Teams.Management.Layout
  alias Plausible.Billing.EnterprisePlan

  alias PlausibleWeb.Router.Helpers, as: Routes

  alias Plausible.Repo
  import Ecto.Query

  def update(assigns, socket) do
    team = socket.assigns[:team] || Resource.Team.get(assigns[:resource_id])
    changeset = Plausible.Teams.Team.crm_changeset(team, %{})
    form = to_form(changeset)

    usage = Teams.Billing.quota_usage(team, with_features: true)

    limits = %{
      monthly_pageviews: Teams.Billing.monthly_pageview_limit(team),
      sites: Teams.Billing.site_limit(team),
      team_members: Teams.Billing.team_member_limit(team)
    }

    plans = get_plans(team.id)
    layout = Layout.init(team)

    any_owner = Plausible.Repo.preload(team, [:owners]).owners |> hd()
    sites = Teams.Sites.list(any_owner, %{}, team: team)

    plan_form =
      to_form(
        EnterprisePlan.changeset(
          %EnterprisePlan{},
          %{site_limit: "10,000"}
        )
      )

    {:ok,
     assign(socket,
       sites: sites,
       plans: plans,
       team: team,
       plan_form: plan_form,
       layout: layout,
       form: form,
       tab: assigns[:tab] || "overview",
       usage: usage,
       limits: limits,
       show_plan_form?: false
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <script type="text/javascript">
        function numberFormatCallback(e) {
          console.info(e)
          console.info(e.target)
          console.info(e.target.value)
          const numeric = Number(e.target.value.replace(/[^0-9]/g, ''))
          const value = numeric > 0 ? new Intl.NumberFormat("en-GB").format(numeric) : ''
          e.target.value = value
        }
      </script>
      <div class="overflow-hidden rounded-lg">
        <div class="p-6">
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
                <p class="text-sm font-medium">
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
              class="col-start-1 row-start-1 w-full appearance-none rounded-md py-2 pl-3 pr-8 text-base text-gray-900 outline outline-1 -outline-offset-1 outline-gray-300 focus:outline focus:outline-2 focus:-outline-offset-2 focus:outline-indigo-600"
            >
              <option>Overview</option>
              <option>Sites</option>
              <option>Members</option>
              <option>Billing</option>
            </select>
          </div>
          <div class="hidden sm:block">
            <nav
              class="isolate flex divide-x dark:divide-gray-900 divide-gray-200 rounded-lg shadow dark:shadow-none"
              aria-label="Tabs"
            >
              <.tab to="overview" target={@myself} tab={@tab}>Overview</.tab>
              <.tab to="members" target={@myself} tab={@tab}>
                Members ({number_format(@usage.team_members)}/{number_format(@limits.team_members)})
              </.tab>
              <.tab to="sites" target={@myself} tab={@tab}>
                Sites ({number_format(@usage.sites)}/{number_format(@limits.sites)})
              </.tab>
              <.tab to="billing" target={@myself} tab={@tab}>
                Billing
              </.tab>
            </nav>
          </div>
        </div>

        <div
          :if={!@show_plan_form?}
          class="grid grid-cols-1 divide-y border-t sm:grid-cols-3 sm:divide-x sm:divide-y-0 dark:bg-gray-900 text-gray-900 dark:text-gray-400 dark:divide-gray-800 dark:border-gray-600"
        >
          <div class="px-6 py-5 text-center text-sm font-medium">
            <span>
              <strong>Subscription status</strong> <br />{subscription_status(@team)}
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
            </span>
          </div>
        </div>

        <div :if={@tab == "billing"} class="mt-2 text-gray-900 dark:text-gray-400">
          <div class="bg-gray-100 dark:bg-gray-900 dark:border dark:border-gray-500 p-4 rounded-md mt-8 mb-8">
            <span class="">
              <p>
                <strong>Usage</strong> <br />
                <ul>
                  <li :for={
                    {cycle, date, total, limit} <-
                      monthly_pageviews_usage(@usage.monthly_pageviews, @limits.monthly_pageviews)
                  }>
                    {cycle} ({date}): <strong>{number_format(total)}</strong> / {number_format(limit)}
                  </li>
                </ul>
              </p>
            </span>

            <p class="mt-4">
              <strong>Features used: </strong>
              <span>{@usage.features |> Enum.map(& &1.display_name) |> Enum.join(", ")}</span>
            </p>
          </div>

          <.table :if={!@show_plan_form?} rows={@plans}>
            <:thead>
              <.th>Created</.th>
              <.th>Interval</.th>
              <.th>PaddlePlan ID</.th>
              <.th>Limits</.th>
              <.th>Features</.th>
            </:thead>
            <:tbody :let={plan}>
              <.td>{plan.inserted_at}</.td>
              <.td>{plan.billing_interval}</.td>
              <.td>{plan.paddle_plan_id}</.td>
              <.td>
                <.tooltip sticky?={false}>
                  <:tooltip_content>
                    <div class="flex justify-between">
                      <span>Pageviews</span> <span>{number_format(plan.monthly_pageview_limit)}</span>
                    </div>
                    <div class="flex justify-between">
                      <span>Sites</span> <span>{number_format(plan.site_limit)}</span>
                    </div>
                    <div class="flex justify-between">
                      <span>Members</span> <span>{number_format(plan.team_member_limit)}</span>
                    </div>
                    <div class="flex justify-between">
                      <span>API Requests</span>
                      <span>{number_format(plan.hourly_api_request_limit)} / hour</span>
                    </div>
                  </:tooltip_content>
                  <a href={} target="_blank" rel="noopener noreferrer">
                    <Heroicons.information_circle class="text-indigo-700 dark:text-gray-500 w-5 h-5 hover:stroke-2" />
                  </a>
                </.tooltip>
              </.td>
              <.td>
                <.tooltip sticky?={false}>
                  <:tooltip_content>
                    <span :for={f <- plan.features}>
                      {f.display_name()}<br />
                    </span>
                  </:tooltip_content>
                  {plan.features |> Enum.map(& &1.display_name()) |> Enum.join(", ")}
                </.tooltip>
              </.td>
            </:tbody>
          </.table>

          <.form
            :let={f}
            :if={@show_plan_form?}
            for={@plan_form}
            phx-submit="save-plan"
            phx-target={@myself}
          >
            <.input field={f[:paddle_plan_id]} label="Paddle Plan ID" autocomplete="off" />
            <.input
              type="select"
              options={["monthly", "yearly"]}
              field={f[:billing_interval]}
              label="Billing Interval"
              autocomplete="off"
            />

            <.input
              onchange="numberFormatCallback(event)"
              onkeyup="numberFormatCallback(event)"
              field={f[:monthly_pageview_limit]}
              label="Monthly Pageview Limit"
              autocomplete="off"
            />
            <.input
              onchange="numberFormatCallback(event)"
              onkeyup="numberFormatCallback(event)"
              field={f[:site_limit]}
              label="Site Limit"
              autocomplete="off"
            />
            <.input
              onchange="numberFormatCallback(event)"
              onkeyup="numberFormatCallback(event)"
              field={f[:team_member_limit]}
              label="Team Member Limit"
              autocomplete="off"
            />
            <.input
              onchange="numberFormatCallback(event)"
              onkeyup="numberFormatCallback(event)"
              field={f[:hourly_api_request_limit]}
              label="Hourly API Request Limit"
              autocomplete="off"
            />

            <.input
              :for={mod <- Plausible.Billing.Feature.list()}
              :if={not mod.free?()}
              type="checkbox"
              name={"#{f.name}[features[]][]"}
              value={mod.name()}
              label={mod.display_name()}
            />

            <.button type="submit">
              Save Custom Plan
            </.button>
          </.form>

          <.button :if={!@show_plan_form?} phx-click="show-plan-form" phx-target={@myself}>
            New Custom Plan
          </.button>
          <.button
            :if={@show_plan_form?}
            theme="bright"
            phx-click="hide-plan-form"
            phx-target={@myself}
          >
            Cancel
          </.button>
        </div>

        <div :if={@tab == "overview"} class="mt-8">
          <.form :let={f} for={@form} phx-submit="change" phx-target={@myself}>
            <.input field={f[:trial_expiry_date]} label="Trial Expiry Date" />
            <.input field={f[:accept_traffic_until]} label="Accept  traffic Until" />
            <.input
              type="checkbox"
              field={f[:allow_next_upgrade_override]}
              label="Allow Next Upgrade Override"
            />

            <.input type="textarea" field={f[:notes]} label="Notes" />
            <.button type="submit">
              Save
            </.button>
          </.form>
        </div>

        <div :if={@tab == "sites"} class="mt-2">
          <.table rows={@sites.entries}>
            <:thead>
              <.th>Domain</.th>
              <.th>Previous Domain</.th>
              <.th invisible>Settings</.th>
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
              <.td>{site.domain_changed_from || "--"}</.td>
              <.td>
                <.styled_link
                  new_tab={true}
                  href={Routes.stats_path(PlausibleWeb.Endpoint, :stats, site.domain, [])}
                >
                  Dashboard
                </.styled_link>
              </.td>
              <.td>
                <.styled_link
                  new_tab={true}
                  href={Routes.site_path(PlausibleWeb.Endpoint, :settings_general, site.domain, [])}
                >
                  Settings
                </.styled_link>
              </.td>
            </:tbody>
          </.table>
        </div>

        <div :if={@tab == "members"} class="mt-2">
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

  def handle_event("show-plan-form", _, socket) do
    {:noreply, assign(socket, show_plan_form?: true)}
  end

  def handle_event("hide-plan-form", _, socket) do
    {:noreply, assign(socket, show_plan_form?: false)}
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

  def handle_event("save-plan", %{"enterprise_plan" => params}, socket) do
    params = Map.put(params, "features", Enum.reject(params["features[]"], &(&1 == "false")))
    params = sanitize_params(params)
    changeset = EnterprisePlan.changeset(%EnterprisePlan{team_id: socket.assigns.team.id}, params)

    case Plausible.Repo.insert(changeset) do
      {:ok, _plan} ->
        success(socket, "Plan saved")
        plans = get_plans(socket.assigns.team.id)

        {:noreply,
         assign(socket, plans: plans, plan_form: to_form(changeset), show_plan_form?: false)}

      {:error, changeset} ->
        failure(socket, "Error saving team: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, plan_form: to_form(changeset))}
    end
  end

  def handle_event("unlock", _, socket) do
    {:noreply, unlock_team(socket)}
  end

  def handle_event("lock", _, socket) do
    {:noreply, lock_team(socket)}
  end

  def team_bg(term) do
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

  defp get_plans(team_id) do
    Repo.all(
      from ep in EnterprisePlan,
        where: ep.team_id == ^team_id,
        order_by: [desc: :id]
    )
  end

  def number_format(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0,")
    |> String.reverse()
  end

  def number_format(other), do: other

  @numeric_fields [
    "team_id",
    "paddle_plan_id",
    "monthly_pageview_limit",
    "site_limit",
    "team_member_limit",
    "hourly_api_request_limit"
  ]

  defp sanitize_params(params) do
    params
    |> Enum.map(&clear_param/1)
    |> Enum.reject(&(&1 == ""))
    |> Map.new()
  end

  defp clear_param({key, value}) when key in @numeric_fields do
    value =
      value
      |> to_string()
      |> String.replace(~r/[^0-9-]/, "")
      |> String.trim()

    {key, value}
  end

  defp clear_param({key, value}) when is_binary(value) do
    {key, String.trim(value)}
  end

  defp clear_param(other) do
    other
  end
end
