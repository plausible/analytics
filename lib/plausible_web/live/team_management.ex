defmodule PlausibleWeb.Live.TeamManagement do
  @moduledoc """
  Live view for enqueuing and applying team membership adjustments.
  """
  use PlausibleWeb, :live_view

  alias Plausible.Teams
  alias Plausible.Auth.User
  import PlausibleWeb.Live.Components.Team

  alias Plausible.Teams.Management.Layout

  def mount(_params, _session, socket) do
    {:ok, reset(socket)}
  end

  defp reset(%{assigns: %{current_user: current_user, my_team: my_team}} = socket) do
    {:ok, my_role} = Teams.Memberships.team_role(my_team, current_user)
    # XXX handle redirect here
    true = my_role in [:owner, :admin]

    layout = Layout.init(my_team, current_user)

    assign(socket,
      layout: layout,
      my_role: my_role,
      team_layout_changed?: false,
      input_role: :viewer,
      input_email: ""
    )
  end

  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />
    <div>
      <.form id="team-layout-form" for={} phx-submit="input-invitation" phx-change="form-changed">
        <div class="flex gap-x-3">
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

      <.member
        :for={{email, entry} <- Layout.sorted_for_display(@layout)}
        :if={entry.queued_op != :delete}
        user={%User{email: entry.email, name: entry.name}}
        role={entry.role}
        label={entry.label}
        my_role={@my_role}
        remove_disabled={not Layout.removable?(@layout, email)}
      />

      <.button
        id="save-layout"
        type="submit"
        phx-click="save-team-layout"
        disabled={not @team_layout_changed?}
      >
        Save changes
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

    existing_entry = Layout.get(layout, email)

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
          |> put_live_flash(
            :success,
            "Invitation pending. Will be sent once you save changes"
          )

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
        %{assigns: %{layout: layout, my_team: my_team, current_user: current_user}} = socket
      ) do
    result = Layout.persist(layout, %{current_user: current_user, my_team: my_team})

    socket =
      case result do
        {:ok, _} ->
          socket
          |> reset()
          |> put_live_flash(:success, "Team layout updated successfully")

        {:error, {:over_limit, limit}} ->
          socket
          |> put_live_flash(
            :error,
            "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit"
          )

        {:error, error} ->
          socket
          |> put_live_flash(:error, inspect(error))
      end

    {:noreply, socket}
  end

  def handle_event("remove-member", %{"email" => email}, %{assigns: %{layout: layout}} = socket) do
    socket =
      case Layout.verify_removable(layout, email) do
        :ok ->
          socket
          |> update_layout(Layout.schedule_delete(layout, email))
          |> put_live_flash(
            :success,
            "Team layout change will be effective once you save your changes"
          )

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

    {:noreply, socket}
  end

  defp valid_email?(email) do
    String.contains?(email, "@") and String.contains?(email, ".")
  end

  defp update_layout(socket, layout) do
    assign(socket,
      layout: layout,
      team_layout_changed?: true
    )
  end
end
