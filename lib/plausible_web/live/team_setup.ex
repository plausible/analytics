defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Teams
  alias PlausibleWeb.Live.Components.ComboBox
  alias Plausible.Teams.Invitations.Candidates
  alias Plausible.Auth.User

  def mount(params, _session, socket) do
    my_team = socket.assigns.my_team
    enabled? = Teams.enabled?(my_team)

    # XXX: remove dev param, once manual testing is considered done
    socket =
      case {enabled?, my_team, params["dev"]} do
        {true, %Teams.Team{setup_complete: true}, nil} ->
          socket
          |> put_flash(:success, "Your team is now setup")
          |> redirect(to: "/settings/team/general")

        {true, %Teams.Team{}, _} ->
          all_candidates =
            my_team
            |> Candidates.search_site_guests("")
            |> Enum.map(fn user ->
              {user.email, "#{user.name} <#{user.email}>"}
            end)

          candidates_selected = %{}
          team_name_changeset = Teams.Team.name_changeset(my_team)

          assign(socket,
            all_candidates: all_candidates,
            team_name_changeset: team_name_changeset,
            candidates_selected: candidates_selected
          )

        {false, _, _} ->
          socket
          |> put_flash(:error, "You cannot set up any team just yet")
          |> redirect(to: "/sites")
      end

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
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
        <.input type="text" field={f[:name]} label="Name" width="w-1/2" phx-debounce="500" />

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
            options={
              reject_already_selected("team-member-candidates", @all_candidates, @candidates_selected)
            }
            on_selection_made={
              fn email, _by_id ->
                send(self(), {:candidate_selected, %{email: email, role: :viewer}})
              end
            }
            suggest_fun={
              fn input, _options ->
                exclude_emails =
                  Enum.map(@candidates_selected, fn {{email, _}, _} -> email end)

                @my_team
                |> Candidates.search_site_guests(input, exclude: exclude_emails)
                |> Enum.map(fn user -> {user.email, "#{user.name} <#{user.email}>"} end)
              end
            }
          />
        </div>
      </.form>

      <.member user={@current_user} role={:owner} you?={true} />

      <%= for {{email, name}, role} <- @candidates_selected do %>
        <.member user={%User{email: email, name: name}} role={role} />
      <% end %>

      <:footer>
        <.button phx-click="setup-team" type="submit" mt?={false} class="w-full">
          Create team
        </.button>
      </:footer>
    </.focus_box>
    """
  end

  attr :user, User, required: true
  attr :you?, :boolean, default: false
  attr :role, :atom, default: nil

  def member(assigns) do
    ~H"""
    <div class="member mt-4">
      <div class="flex items-center gap-x-5">
        <img src={User.profile_img_url(@user)} class="w-7 rounded-full" />
        <span class="text-sm">
          {@user.name}

          <span
            :if={@you?}
            class="ml-1 dark:bg-indigo-600 dark:text-gray-200 bg-gray-100 text-gray-500 text-xs px-1 rounded"
          >
            You
          </span>

          <br /><span class="text-gray-500 text-xs">{@user.email}</span>
        </span>
        <div class="flex-1 text-right">
          <.dropdown class="relative">
            <:button class="role bg-transparent text-gray-800 dark:text-gray-100 hover:bg-gray-50 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate inline-flex items-center gap-x-2 font-medium rounded-md px-3.5 py-2.5 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700">
              {@role |> to_string() |> String.capitalize()}
              <Heroicons.chevron_down mini class="size-4 mt-0.5" />
            </:button>
            <:menu class="dropdown-items max-w-60">
              <.dropdown_item
                href="#"
                disabled={@you? or @role == :admin}
                phx-click="update-role"
                phx-value-role={:admin}
                phx-value-email={@user.email}
                phx-value-name={@user.name}
              >
                <div>Admin</div>
                <div class="text-gray-500 dark:text-gray-400 text-xs/5">
                  Manage all team settings
                </div>
              </.dropdown_item>

              <.dropdown_item
                href="#"
                disabled={@you? or @role == :editor}
                phx-click="update-role"
                phx-value-role={:editor}
                phx-value-email={@user.email}
                phx-value-name={@user.name}
              >
                <div>Editor</div>
                <div class="text-gray-500 dark:text-gray-400 text-xs/5">
                  Create and view new sites
                </div>
              </.dropdown_item>

              <.dropdown_item
                href="#"
                disabled={@you? or @role == :viewer}
                phx-click="update-role"
                phx-value-role={:viewer}
                phx-value-email={@user.email}
                phx-value-name={@user.name}
              >
                <div>Viewer</div>
                <div class="text-gray-500 dark:text-gray-400 text-xs/5">
                  Can only view all sites under your team
                </div>
              </.dropdown_item>

              <.dropdown_divider />
              <.dropdown_item
                href="#"
                disabled={@you?}
                phx-click="remove-member"
                phx-value-email={@user.email}
                phx-value-name={@user.name}
              >
                <div class="text-red-600 hover:text-red-600 dark:text-red-500 hover:dark:text-red-400">
                  Remove member
                </div>
                <div class="text-gray-500 dark:text-gray-400 text-xs/5">
                  Remove member from your team
                </div>
              </.dropdown_item>
            </:menu>
          </.dropdown>
        </div>
      </div>
    </div>
    """
  end

  def handle_info(
        {:candidate_selected, %{email: email, role: role}},
        %{assigns: %{my_team: team, candidates_selected: candidates, current_user: current_user}} =
          socket
      ) do
    socket =
      case Candidates.get_site_guest(team, email) do
        %User{} = user ->
          assign(
            socket,
            :candidates_selected,
            Map.put(candidates, {user.email, user.name}, role)
          )

        nil ->
          if valid_email?(email) and email != current_user.email do
            assign(
              socket,
              :candidates_selected,
              Map.put(candidates, {email, "Invited User"}, role)
            )
          else
            put_live_flash(
              socket,
              :error,
              "Sorry, e-mail '#{email}' is invalid. Please type the address again."
            )
          end
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

  def handle_event("update-role", %{"name" => name, "email" => email, "role" => role}, socket) do
    updated_candidates =
      Map.put(socket.assigns.candidates_selected, {email, name}, String.to_existing_atom(role))

    {:noreply, assign(socket, candidates_selected: updated_candidates)}
  end

  def handle_event("remove-member", %{"name" => name, "email" => email}, socket) do
    updated_candidates = Map.delete(socket.assigns.candidates_selected, {email, name})
    {:noreply, assign(socket, candidates_selected: updated_candidates)}
  end

  def handle_event("setup-team", %{}, socket) do
    candidates = socket.assigns.candidates_selected
    team = socket.assigns.my_team
    inviter = Repo.preload(team, :owner).owner

    result =
      Repo.transaction(fn ->
        team
        |> Teams.Team.setup_changeset()
        |> Repo.update!()

        Enum.map(
          candidates,
          fn {{email, _name}, role} ->
            case Teams.Invitations.InviteToTeam.invite(team, inviter, email, role,
                   send_email?: false
                 ) do
              {:ok, invitation} -> invitation
              {:error, error} -> Repo.rollback(error)
            end
          end
        )
      end)

    case result do
      {:ok, invitations} ->
        Enum.each(invitations, fn invitation ->
          invitee = Plausible.Auth.find_user_by(email: invitation.email)
          Teams.Invitations.InviteToTeam.send_invitation_email(invitation, invitee)
        end)

        socket =
          socket
          |> put_flash(:success, "Your team is now setup")
          |> redirect(to: "/settings/team/general")

        {:noreply, socket}

      {:error, {:over_limit, limit}} ->
        socket =
          socket
          |> put_live_flash(
            :error,
            "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit."
          )

        {:noreply, socket}
    end
  end

  defp valid_email?(email) do
    String.contains?(email, "@") and String.contains?(email, ".")
  end

  defp reject_already_selected(combo_box, candidates, candidates_selected) do
    result =
      candidates
      |> Enum.reject(fn {email, _} ->
        Enum.find(candidates_selected, fn
          {{^email, _}, _} -> true
          _ -> false
        end)
      end)

    send_update(PlausibleWeb.Live.Components.ComboBox, id: combo_box, suggestions: result)
    result
  end
end
