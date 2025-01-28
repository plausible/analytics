defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  alias Plausible.Auth.User
  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Invitations.Candidates
  alias Plausible.Teams.Management.Layout
  alias PlausibleWeb.Live.Components.ComboBox
  alias PlausibleWeb.Router.Helpers, as: Routes

  import PlausibleWeb.Live.Components.Team

  def mount(params, _session, socket) do
    my_team = socket.assigns.my_team
    enabled? = Teams.enabled?(my_team)

    # XXX: remove dev param, once manual testing is considered done
    socket =
      case {enabled?, my_team, params["dev"]} do
        {true, %Teams.Team{setup_complete: true}, nil} ->
          socket
          |> put_flash(:success, "Your team is now setup")
          |> redirect(to: Routes.settings_path(socket, :team_general))

        {true, %Teams.Team{}, _} ->
          all_candidates =
            my_team
            |> Candidates.search_site_guests("")
            |> Enum.map(fn user ->
              {user.email, "#{user.name} <#{user.email}>"}
            end)

          team_name_changeset = Teams.Team.name_changeset(my_team)

          layout =
            Layout.init(my_team, socket.assigns.current_user)

          assign(socket,
            all_candidates: all_candidates,
            team_name_changeset: team_name_changeset,
            team_layout: layout
          )

        {false, _, _} ->
          socket
          |> put_flash(:error, "You cannot set up any team just yet")
          |> redirect(to: Routes.site_path(socket, :index))
      end

    socket =
      if my_team do
        {:ok, my_role} = Teams.Memberships.team_role(my_team, socket.assigns.current_user)
        assign(socket, my_role: my_role)
      else
        socket
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />
    <.focus_box>
      <:title>Create a new team</:title>
      <:subtitle>
        Add members and assign roles to manage different sites access efficiently
      </:subtitle>

      <.form :let={f} for={@team_name_changeset} method="post" phx-change="update-team">
        <.input type="text" field={f[:name]} label="Name" width="w-full" phx-debounce="500" />

        <div class="mt-4">
          <.label>
            Add members
          </.label>

          <.live_component
            id="team-member-candidates"
            submit_name="team-member-candidate"
            class="py-2"
            module={ComboBox}
            clear_on_select
            creatable
            creatable_prompt="Send invitation to email:"
            placeholder="Select existing member or type email address to invite"
            options={reject_already_selected(@all_candidates, @team_layout)}
            on_selection_made={
              fn email, _by_id ->
                send(self(), {:candidate_selected, %{email: email, role: :viewer}})
              end
            }
            suggest_fun={
              fn input, _options ->
                exclude_emails =
                  Enum.map(@team_layout, fn {email, _} -> email end)

                @my_team
                |> Candidates.search_site_guests(input, exclude: exclude_emails)
                |> Enum.map(fn user -> {user.email, "#{user.name} <#{user.email}>"} end)
              end
            }
          />
        </div>
      </.form>

      <.member
        :for={{email, entry} <- Layout.sorted_for_display(@team_layout)}
        :if={entry.queued_op != :delete}
        user={%User{email: entry.email, name: entry.name}}
        role={entry.role}
        label={entry.label}
        my_role={@my_role}
        disabled={@current_user.email == email}
        remove_disabled={not Layout.removable?(@team_layout, email)}
      />

      <:footer>
        <.button phx-click="setup-team" type="submit" mt?={false} class="w-full">
          Create team
        </.button>
      </:footer>
    </.focus_box>
    """
  end

  def handle_info(
        {:candidate_selected, %{email: email, role: role}},
        %{assigns: %{my_team: team, team_layout: layout}} =
          socket
      ) do
    email = String.trim(email)
    existing_entry = Layout.get(layout, email)
    existing_guest = Candidates.get_site_guest(team, email)

    socket =
      cond do
        existing_entry && existing_entry.queued_op == :delete ->
          assign(socket, layout: Layout.update_role(layout, email, role))

        existing_entry ->
          put_flash(
            socket,
            :error,
            "Make sure the e-mail is valid and is not taken already in your team layout"
          )

        valid_email?(email) && existing_guest ->
          assign(
            socket,
            team_layout: Layout.schedule_send(layout, email, role, name: existing_guest.name)
          )

        valid_email?(email) ->
          assign(
            socket,
            team_layout: Layout.schedule_send(layout, email, role)
          )

        true ->
          put_flash(
            socket,
            :error,
            "Sorry, e-mail '#{email}' is invalid. Please type the address again"
          )
      end

    {:noreply, socket}
  end

  def handle_event("update-team", %{"team" => params}, socket) do
    team_name_changeset =
      socket.assigns.my_team
      |> Teams.Team.name_changeset(params)

    if team_name_changeset.valid? do
      my_team = Repo.update!(team_name_changeset)

      {:noreply,
       assign(socket,
         team_name_changeset: team_name_changeset,
         my_team: my_team
       )}
    else
      {:noreply, socket}
    end
  end

  @roles Plausible.Teams.Membership.roles() -- [:guest]
  @roles_cast_map Enum.into(@roles, %{}, fn role -> {to_string(role), role} end)

  def handle_event(
        "update-role",
        %{"email" => email, "role" => role},
        %{assigns: %{team_layout: layout}} = socket
      ) do
    layout = Layout.update_role(layout, email, Map.fetch!(@roles_cast_map, role))

    {:noreply, assign(socket, team_layout: layout)}
  end

  def handle_event(
        "remove-member",
        %{"email" => email},
        %{assigns: %{team_layout: layout}} = socket
      ) do
    socket =
      case Layout.verify_removable(layout, email) do
        :ok ->
          assign(socket, team_layout: Layout.schedule_delete(layout, email))

        {:error, _} ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event(
        "setup-team",
        %{},
        %{assigns: %{team_layout: layout, current_user: current_user, my_team: my_team}} = socket
      ) do
    my_team
    |> Teams.Team.setup_changeset()
    |> Repo.update!()

    result =
      Layout.persist(layout, %{current_user: current_user, my_team: my_team})

    socket =
      case result do
        {:ok, _} ->
          socket
          |> put_flash(:success, "Your team is now setup")
          |> redirect(to: Routes.settings_path(socket, :team_general))

        {:error, {:over_limit, limit}} ->
          put_flash(
            socket,
            :error,
            "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit."
          )
      end

    {:noreply, socket}
  end

  defp valid_email?(email) do
    String.contains?(email, "@") and String.contains?(email, ".")
  end

  defp reject_already_selected(candidates, layout) do
    candidates
    |> Enum.reject(fn {email, _} ->
      not is_nil(Layout.get(layout, email))
    end)
  end
end
