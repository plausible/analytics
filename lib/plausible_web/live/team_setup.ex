defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Invitations.Candidates
  alias Plausible.Teams.Management.Layout
  alias PlausibleWeb.Router.Helpers, as: Routes

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

          layout = Layout.init(my_team)

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
    <.focus_box>
      <:title>Create a new team</:title>
      <:subtitle>
        Add members and assign roles to manage different sites access efficiently
      </:subtitle>

      <.form
        :let={f}
        for={@team_name_changeset}
        method="post"
        phx-change="update-team"
        id="update-team-form"
        class="mt-4 mb-8"
      >
        <.input type="text" field={f[:name]} label="Name" width="w-full" phx-debounce="500" />
      </.form>

      <.label class="mb-2">
        Team Members
      </.label>
      {live_render(@socket, PlausibleWeb.Live.TeamManagement,
        id: "team-management-setup",
        container: {:div, id: "team-setup"},
        session: %{
          "mode" => "team-setup"
        }
      )}
    </.focus_box>
    """
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
end
