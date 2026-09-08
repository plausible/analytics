defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  alias Plausible.Teams
  alias PlausibleWeb.Router.Helpers, as: Routes

  def mount(_params, _session, socket) do
    socket =
      case socket.assigns.current_team do
        %Teams.Team{setup_complete: true} ->
          socket
          |> put_flash(:success, "Your team is now created")
          |> redirect(to: Routes.settings_path(socket, :team_general))

        %Teams.Team{} ->
          socket

        _ ->
          socket
          |> put_flash(:error, "You cannot create any team just yet")
          |> redirect(to: Routes.site_path(socket, :index))
      end

    {:ok, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, :locked?, Plausible.Teams.Billing.solo?(assigns.current_team))

    ~H"""
    <.focus_box padding?={false}>
      <:title>
        <div class="pt-8 px-8 flex justify-between">
          <div>Create a new team</div>
          <div class="ml-auto">
            <.docs_info slug="users-roles" />
          </div>
        </div>
      </:title>
      <:subtitle>
        <p class="px-8">
          Name your team, add team members and assign roles. When ready, click "Create Team" to send invitations
        </p>
      </:subtitle>

      <div class="relative -mt-8 pt-4 pb-8 px-8">
        <PlausibleWeb.Components.Billing.feature_gate
          current_user={@current_user}
          current_team={@current_team}
          locked?={@locked?}
        >
          {live_render(@socket, PlausibleWeb.Live.TeamManagement,
            id: "team-management-setup",
            container: {:div, id: "team-setup"},
            session: %{
              "mode" => "team-setup"
            }
          )}
        </PlausibleWeb.Components.Billing.feature_gate>
      </div>
    </.focus_box>
    """
  end
end
