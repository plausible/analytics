defmodule PlausibleWeb.Live.TeamManagement do
  @moduledoc """
  Live view for enqueuing and applying team membership adjustments.
  """
  use PlausibleWeb, :live_view

  alias Plausible.Teams
  import PlausibleWeb.Live.Components.Team

  alias Plausible.Teams.Management.Layout

  def mount(_params, _session, socket) do
    {:ok, reset(socket)}
  end

  defp reset(%{assigns: %{current_user: current_user, current_team: current_team}} = socket) do
    {:ok, my_role} = Teams.Memberships.team_role(current_team, current_user)

    layout = Layout.init(current_team)
    team_members_limit = Plausible.Teams.Billing.team_member_limit(current_team)

    assign(socket,
      team_members_limit: team_members_limit,
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

    <PlausibleWeb.Components.Billing.Notice.limit_exceeded
      :if={@team_members_limit != 0 and at_limit?(@layout, @team_members_limit)}
      current_user={@current_user}
      current_team={@current_team}
      limit={@team_members_limit}
      resource="members"
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
              placeholder="Enter e-mail"
              phx-debounce={200}
              readonly={at_limit?(@layout, @team_members_limit) or @my_role not in [:admin, :owner]}
              mt?={false}
            />
          </div>

          <.dropdown id="input-role-picker">
            <:button class="role inline-flex items-center gap-x-2 font-medium rounded-md px-3 py-2 text-sm border border-gray-300 dark:border-gray-750 rounded-md text-gray-800 dark:text-gray-100 dark:bg-gray-750 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate shadow-xs hover:shadow-sm transition-all duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700">
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

          <.button
            id="invite-member"
            type="submit"
            mt?={false}
            disabled={at_limit?(@layout, @team_members_limit) or @my_role not in [:admin, :owner]}
          >
            Invite
          </.button>
        </div>
      </.form>

      <.member_list layout={@layout} my_role={@my_role} current_user={@current_user} />
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
    socket
    |> assign(layout: layout, team_layout_changed?: true)
    |> save_team_layout()
  end

  defp save_team_layout(
         %{assigns: %{layout: layout, current_team: current_team, current_user: current_user}} =
           socket
       ) do
    result =
      Layout.persist(layout, %{
        current_user: current_user,
        current_team: Plausible.Repo.reload!(current_team)
      })

    case result do
      {:ok, _} ->
        case Teams.Memberships.team_role(current_team, current_user) do
          {:ok, role} when role in [:viewer, :billing, :editor] ->
            redirect(socket,
              to: Routes.settings_path(socket, :team_general, __team: current_team.identifier)
            )

          {:ok, _} ->
            reset(socket)

          {:error, :not_a_member} ->
            redirect(socket, to: Routes.site_path(socket, :index, __team: "none"))
        end

      {:error, error} ->
        put_live_flash(socket, :error, persist_error_message(error))
    end
  end
end
