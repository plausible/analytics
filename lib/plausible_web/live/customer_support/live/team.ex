defmodule PlausibleWeb.CustomerSupport.Live.Team do
  use Plausible.CustomerSupport.Resource, :component

  alias Plausible.Billing.Subscription

  import PlausibleWeb.Live.Components.Team
  alias Plausible.Teams.Management.Layout

  def update(assigns, socket) do
    team = Resource.Team.get(assigns.resource_id)
    layout = Layout.init(team)
    changeset = Plausible.Teams.Team.crm_changeset(team, %{})
    form = to_form(changeset)
    {:ok, assign(socket, layout: layout, team: team, form: form)}
  end

  # def render(assigns) do
  #   ~H"""
  #   <div>
  #     <div>
  #       {@team.name} owned by
  #       <div :for={o <- @team.owners}>
  #         <.styled_link phx-click="open" phx-value-id={o.id} phx-value-type="user">
  #           {o.name} {o.email}
  #         </.styled_link>
  #       </div>
  #       <.form :let={f} for={@form} phx-submit="change" phx-target={@myself}>
  #         <.input field={f[:trial_expiry_date]} />
  #         <.button type="submit">
  #           Change
  #         </.button>
  #       </.form>
  #     </div>
  #   </div>
  #   """
  # end

  def render(assigns) do
    ~H"""
    <div class="overflow-hidden rounded-lg bg-white shadow">
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
              <p class="text-xl font-bold text-gray-900 sm:text-2xl">{@team.name}</p>
              <p class="text-sm font-medium text-gray-600">
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

      <div class="m-4">
        <h3 class="text-sm/6 font-medium text-gray-900">Members</h3>
        <div class="mt-2">
          <.member
            :for={{_email, entry} <- Layout.sorted_for_display(@layout)}
            user={%Plausible.Auth.User{email: entry.email, name: entry.name}}
            role={entry.role}
            label={entry_label(entry)}
            my_role={:superadmin}
            disabled={true}
          />
        </div>
      </div>

      <div class="p-4">
        <.form :let={f} for={@form} phx-submit="change" phx-target={@myself}>
          <.input field={f[:trial_expiry_date]} />
          <.button type="submit">
            Change
          </.button>
        </.form>
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
        {:noreply, assign(socket, team: team, form: to_form(changeset))}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
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
          assigns = %{}

          ~H"""
          <.styled_link new_tab={true} href={manage_url(team.subscription)}>{status_str}</.styled_link>
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

      assigns = %{}

      ~H"""
      <.styled_link new_tab={true} href={manage_url(subscription)}>{quota} ({interval})</.styled_link>
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

  defp lock(team) do
    if team.grace_period do
      Plausible.Billing.SiteLocker.set_lock_status_for(team, true)
      Plausible.Teams.end_grace_period(team)
      {:ok, team}
    else
      {:error, team, "No active grace period on this team"}
    end
  end

  defp unlock(team) do
    if team.grace_period do
      Plausible.Teams.remove_grace_period(team)
      Plausible.Billing.SiteLocker.set_lock_status_for(team, false)
      {:ok, team}
    else
      {:error, team, "No active grace period on this team"}
    end
  end

  defp entry_label(%Layout.Entry{role: :guest, type: :membership}), do: nil
  defp entry_label(%Layout.Entry{type: :invitation_pending}), do: "Invitation Pending"
  defp entry_label(%Layout.Entry{type: :invitation_sent}), do: "Invitation Sent"
  defp entry_label(%Layout.Entry{meta: %{user: %{id: id}}}), do: "You"
  defp entry_label(_), do: "Team Member"
end
