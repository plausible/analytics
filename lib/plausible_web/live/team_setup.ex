defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Teams
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
          current_user = socket.assigns.current_user

          team_name_form =
            my_team
            |> Teams.Team.name_changeset(%{name: "#{current_user.name}'s Team"})
            |> Repo.update!()
            |> Teams.Team.name_changeset(%{})
            |> to_form()

          layout = Layout.init(my_team)

          assign(socket,
            team_name_form: team_name_form,
            team_layout: layout,
            my_team: my_team
          )

        {true, nil, _} ->
          socket
          |> put_flash(:error, "You cannot set up any team just yet")
          |> redirect(to: Routes.site_path(socket, :index))

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
      <:title>Setup a new team</:title>
      <:subtitle>
        Add members and assign roles to manage different sites access efficiently
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
    changeset = Teams.Team.name_changeset(socket.assigns.my_team, %{name: name})

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
