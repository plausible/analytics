defmodule PlausibleWeb.Live.TeamManagement do
  @moduledoc """
  Live view for enqueuing and applying team membership adjustments.
  """
  use PlausibleWeb, :live_view

  alias Plausible.Teams
  alias Plausible.Auth.User
  import PlausibleWeb.Live.Components.Team

  alias Plausible.Teams.Management.Layout

  def mount(_params, session, socket) do
    mode =
      if session["mode"] == "team-setup" do
        :team_setup
      else
        :team_management
      end

    {:ok, socket |> assign(mode: mode) |> reset()}
  end

  defp reset(%{assigns: %{current_user: current_user, my_team: my_team}} = socket) do
    {:ok, my_role} = Teams.Memberships.team_role(my_team, current_user)

    if my_role not in [:owner, :admin] do
      redirect(socket, to: Routes.settings_path(socket, :team_general))
    else
      layout = Layout.init(my_team)
      team_members_limit = Plausible.Teams.Billing.team_member_limit(my_team)

      assign(socket,
        attempted_save?: false,
        team_members_limit: team_members_limit,
        layout: layout,
        my_role: my_role,
        team_layout_changed?: false,
        input_role: :viewer,
        input_email: ""
      )
    end
  end

  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />

    <PlausibleWeb.Components.Billing.Notice.limit_exceeded
      :if={
        (not @team_layout_changed? or @attempted_save?) and
          not Plausible.Billing.Quota.below_limit?(
            Layout.active_count(@layout) - 1,
            @team_members_limit
          )
      }
      current_user={@current_user}
      billable_user={@current_user}
      current_team={@my_team}
      limit={@team_members_limit}
      resource="team members"
      class="mb-4"
    />
    <div>
      <.form id="team-layout-form" for={} phx-submit="input-invitation" phx-change="form-changed">
        <div class="flex gap-x-3 mb-8">
          <div class="flex-1">
            <.input
              name="input-email"
              type="email"
              value={@input_email}
              placeholder="Enter e-mail to send invitation to"
              phx-debounce={200}
              mt?={false}
            />
          </div>

          <.dropdown class="relative" id="input-role-picker">
            <:button class="role border rounded border-indigo-700 bg-transparent text-gray-800 dark:text-gray-100 hover:bg-gray-50 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate inline-flex items-center gap-x-2 font-medium rounded-md px-3 py-2 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700">
              {@input_role |> Atom.to_string() |> String.capitalize()}
              <Heroicons.chevron_down mini class="size-4 mt-0.5" />
            </:button>
            <:menu class="dropdown-items max-w-60">
              <.role_item role={:owner} disabled={@my_role != :owner} phx-click="switch-role">
                Manage the team without restrictions
              </.role_item>
              <.role_item
                role={:admin}
                disabled={@my_role not in [:owner, :admin]}
                phx-click="switch-role"
              >
                Manage all team settings
              </.role_item>
              <.role_item
                role={:editor}
                disabled={@my_role not in [:owner, :admin]}
                phx-click="switch-role"
              >
                Create and view new sites
              </.role_item>
              <.role_item
                role={:billing}
                disabled={@my_role not in [:owner, :admin]}
                phx-click="switch-role"
              >
                Manage subscription
              </.role_item>
              <.role_item
                role={:viewer}
                disabled={@my_role not in [:owner, :admin]}
                phx-click="switch-role"
              >
                View all sites under your team
              </.role_item>
            </:menu>
          </.dropdown>

          <.button id="invite-member" type="submit" mt?={false}>
            Invite
          </.button>
        </div>
      </.form>

      <div id="member-list">
        <.member
          :for={{email, entry} <- Layout.sorted_for_display(@layout)}
          :if={entry.queued_op != :delete and entry.role != :guest}
          user={%User{email: entry.email, name: entry.name}}
          role={entry.role}
          label={entry_label(entry, @current_user)}
          my_role={@my_role}
          remove_disabled={not Layout.removable?(@layout, email)}
          disabled={entry.role == :owner && Layout.owners_count(@layout) == 1}
        />
      </div>

      <div :if={Layout.has_guests?(@layout)} class="flex items-center mt-4 mb-4" id="guests-hr">
        <hr class="flex-grow border-t border-gray-200 dark:border-gray-600" />
        <span class="mx-4 text-gray-500 text-sm">
          Guests
        </span>
        <hr class="flex-grow border-t border-gray-200 dark:border-gray-600" />
      </div>

      <div :if={Layout.has_guests?(@layout)} id="guest-list">
        <.member
          :for={{email, entry} <- Layout.sorted_for_display(@layout)}
          :if={entry.queued_op != :delete and entry.role == :guest}
          user={%User{email: entry.email, name: entry.name}}
          role={entry.role}
          label={entry_label(entry, @current_user)}
          my_role={@my_role}
          remove_disabled={not Layout.removable?(@layout, email)}
        />
      </div>

      <.button
        :if={@mode == :team_setup}
        id="save-layout"
        type="submit"
        phx-click="save-team-layout"
        class="mt-8 w-full"
      >
        Create Team
      </.button>
    </div>
    """
  end

  @roles Plausible.Teams.Membership.roles() -- [:guest]
  @roles_cast_map Enum.into(@roles, %{}, fn role -> {to_string(role), role} end)

  def handle_event("form-changed", params, socket) do
    {:noreply, assign(socket, input_email: params["input-email"])}
  end

  def handle_event("switch-role", %{"role" => role}, socket) do
    socket = assign(socket, input_role: Map.fetch!(@roles_cast_map, role))
    {:noreply, socket}
  end

  def handle_event(
        "input-invitation",
        %{"input-email" => email},
        %{assigns: %{layout: layout, input_role: role}} = socket
      ) do
    email = String.trim(email)

    existing_entry = Map.get(layout, email)

    socket =
      cond do
        existing_entry && existing_entry.queued_op == :delete ->
          # bring back previously deleted entry (either invitation or membership), and only update role
          socket
          |> update_layout(Layout.update_role(layout, email, role))
          |> assign(input_email: "")

        existing_entry ->
          # trying to add e-mail that's already in the layout
          socket
          |> assign(input_email: email)
          |> put_live_flash(
            :error,
            "Make sure the e-mail is valid and is not taken already in your team layout"
          )

        valid_email?(email) ->
          socket
          |> update_layout(Layout.schedule_send(layout, email, role))
          |> assign(input_email: "")

        true ->
          socket
          |> assign(input_email: email)
          |> put_live_flash(
            :error,
            "Make sure the e-mail is valid and is not taken already in your team layout"
          )
      end

    {:noreply, socket}
  end

  def handle_event(
        "save-team-layout",
        _params,
        socket
      ) do
    socket = save_team_layout(socket)

    {:noreply, socket}
  end

  def handle_event("remove-member", %{"email" => email}, %{assigns: %{layout: layout}} = socket) do
    socket =
      case Layout.verify_removable(layout, email) do
        :ok ->
          update_layout(socket, Layout.schedule_delete(layout, email))

        {:error, message} ->
          socket
          |> put_live_flash(
            :error,
            message
          )
      end

    {:noreply, socket}
  end

  def handle_event(
        "update-role",
        %{"email" => email, "role" => role},
        %{assigns: %{layout: layout}} = socket
      ) do
    socket =
      update_layout(socket, Layout.update_role(layout, email, Map.fetch!(@roles_cast_map, role)))
      |> push_event("js-exec", %{
        to: "#member-row-#{:erlang.phash2(email)}",
        attr: "data-role-changed"
      })

    {:noreply, socket}
  end

  defp valid_email?(email) do
    String.contains?(email, "@") and String.contains?(email, ".")
  end

  defp update_layout(socket, layout) do
    socket =
      assign(socket,
        layout: layout,
        team_layout_changed?: true
      )

    if socket.assigns.mode == :team_management do
      save_team_layout(socket)
    else
      socket
    end
  end

  defp save_team_layout(
         %{assigns: %{layout: layout, my_team: my_team, current_user: current_user}} = socket
       ) do
    result = Layout.persist(layout, %{current_user: current_user, my_team: my_team})

    socket = assign(socket, attempted_save?: true)

    case {result, socket.assigns.mode} do
      {{:ok, _}, :team_setup} ->
        socket
        |> put_flash(:success, "Your team is now setup")
        |> redirect(to: Routes.settings_path(socket, :team_general))

      {{:ok, _}, :team_management} ->
        socket
        |> reset()
        |> put_live_flash(:success, "Team layout updated successfully")

      {{:error, :only_one_owner}, _} ->
        socket
        |> put_live_flash(
          :error,
          "The team has to have at least one owner"
        )

      {{:error, {:over_limit, limit}}, _} ->
        socket
        |> put_live_flash(
          :error,
          "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit"
        )
    end
  end

  defp entry_label(%Layout.Entry{role: :guest, type: :membership}, _), do: nil
  defp entry_label(%Layout.Entry{type: :invitation_pending}, _), do: "Invitation Pending"
  defp entry_label(%Layout.Entry{type: :invitation_sent}, _), do: "Invitation Sent"
  defp entry_label(%Layout.Entry{meta: %{user: %{id: id}}}, %{id: id}), do: "You"
  defp entry_label(_, _), do: "Team Member"
end
