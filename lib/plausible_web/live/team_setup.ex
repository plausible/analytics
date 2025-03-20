defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Management.Layout
  alias PlausibleWeb.Router.Helpers, as: Routes

  def mount(_params, _session, socket) do
    current_team = socket.assigns.current_team
    enabled? = Teams.enabled?(current_team)

    socket =
      case {enabled?, current_team} do
        {true, %Teams.Team{setup_complete: true}} ->
          socket
          |> put_flash(:success, "Your team is now created")
          |> redirect(to: Routes.settings_path(socket, :team_general))

        {true, %Teams.Team{}} ->
          current_user = socket.assigns.current_user

          team_name_form =
            current_team
            |> Teams.Team.name_changeset(%{name: "#{current_user.name}'s Team"})
            |> Repo.update!()
            |> Teams.Team.name_changeset(%{})
            |> to_form()

          layout = Layout.init(current_team)

          assign(socket,
            team_name_form: team_name_form,
            team_layout: layout,
            current_team: current_team
          )

        {_, _} ->
          socket
          |> put_flash(:error, "You cannot create any team just yet")
          |> redirect(to: Routes.site_path(socket, :index))
      end

    socket =
      if current_team do
        {:ok, my_role} = Teams.Memberships.team_role(current_team, socket.assigns.current_user)
        assign(socket, my_role: my_role)
      else
        socket
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.focus_box>
      <:title>
        <div class="flex justify-between">
          <div>Create a new team</div>
          <div class="ml-auto">
            <.docs_info slug="users-roles" />
          </div>
        </div>
      </:title>
      <:subtitle>
        Add your team members and assign their roles
      </:subtitle>

      <.form
        :let={f}
        for={@team_name_form}
        method="post"
        phx-change="update-team"
        phx-blur="update-team"
        id="update-team-form"
        class="mt-4 mb-8"
      >
        <.input
          type="text"
          placeholder={"#{@current_user.name}'s Team"}
          autofocus
          field={f[:name]}
          label="Name"
          width="w-full"
          phx-debounce="500"
        />
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

  def handle_event("update-team", %{"team" => %{"name" => name}}, socket) do
    changeset = Teams.Team.name_changeset(socket.assigns.current_team, %{name: name})

    socket =
      case Repo.update(changeset) do
        {:ok, _team} ->
          assign(socket, team_name_form: to_form(changeset))

        {:error, changeset} ->
          assign(socket, team_name_form: to_form(changeset))
      end

    {:noreply, socket}
  end
end
