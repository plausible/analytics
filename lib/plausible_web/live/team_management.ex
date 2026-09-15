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

          <.role_picker
            id="input-role-picker"
            role={@input_role}
            my_role={@my_role}
            phx-click="switch-role"
          />

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

      <div id="member-list">
        <.member
          :for={{email, entry} <- Layout.sorted_for_display(@layout)}
          :if={entry.role != :guest}
          user={%User{email: entry.email, name: entry.name}}
          role={entry.role}
          label={entry_label(entry, @current_user)}
          me?={entry.id == @current_user.id}
          my_role={@my_role}
          remove_disabled={not Layout.removable?(@layout, email)}
          disabled={
            (entry.role == :owner && Layout.owners_count(@layout) == 1) or
              @my_role not in [:owner, :admin]
          }
        />
      </div>

      <div :if={Layout.has_guests?(@layout)} class="flex items-center mt-4 mb-4" id="guests-hr">
        <hr class="grow border-t border-gray-200 dark:border-gray-700" />
        <span class="mx-4 text-gray-500 text-sm">
          Guests
        </span>
        <hr class="grow border-t border-gray-200 dark:border-gray-700" />
      </div>

      <div :if={Layout.has_guests?(@layout)} id="guest-list">
        <.member
          :for={{email, entry} <- Layout.sorted_for_display(@layout)}
          :if={entry.role == :guest}
          user={%User{email: entry.email, name: entry.name}}
          role={entry.role}
          label={entry_label(entry, @current_user)}
          my_role={@my_role}
          remove_disabled={not Layout.removable?(@layout, email)}
          disabled={@my_role not in [:owner, :admin]}
        />
      </div>
    </div>
    """
  end

  def handle_event("form-changed", params, socket) do
    {:noreply, assign(socket, input_email: params["input-email"])}
  end

  def handle_event("switch-role", %{"role" => role}, socket) do
    socket = assign(socket, input_role: role_to_atom(role))
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
      update_layout(socket, Layout.update_role(layout, email, role_to_atom(role)))
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

      {:error, :permission_denied} ->
        socket
        |> put_live_flash(
          :error,
          "Permission denied"
        )

      {:error, :only_one_owner} ->
        socket
        |> put_live_flash(
          :error,
          "The team has to have at least one owner"
        )

      {:error, :disabled_2fa} ->
        socket
        |> put_live_flash(
          :error,
          "User must have 2FA enabled to become an owner"
        )

      {:error, {:over_limit, limit}} ->
        socket
        |> put_live_flash(
          :error,
          "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit"
        )
    end
  end

  defp entry_label(%Layout.Entry{role: :guest, type: :membership}, _), do: nil
  defp entry_label(%Layout.Entry{type: :invitation_pending}, _), do: "Invitation pending"
  defp entry_label(%Layout.Entry{type: :invitation_sent}, _), do: "Invitation sent"

  defp entry_label(%Layout.Entry{meta: %{user: %{id: id, type: :sso}}}, %{id: id}),
    do: "You (SSO)"

  defp entry_label(%Layout.Entry{meta: %{user: %{id: id}}}, %{id: id}), do: "You"
  defp entry_label(%Layout.Entry{meta: %{user: %{type: :sso}}}, _), do: "SSO"
  defp entry_label(_, _), do: nil

  def at_limit?(layout, limit) do
    not Plausible.Billing.Quota.below_limit?(
      Layout.active_count(layout) - 1,
      limit
    )
  end
end
