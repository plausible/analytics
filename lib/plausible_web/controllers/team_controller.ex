defmodule PlausibleWeb.TeamController do
  use PlausibleWeb, :controller

  alias Plausible.Teams

  plug PlausibleWeb.RequireAccountPlug

  def update_member_role(conn, %{"id" => user_id, "new_role" => new_role_str}) do
    %{my_team: team, current_user: current_user} = conn.assigns

    case Teams.Memberships.UpdateRole.update(team, user_id, new_role_str, current_user) do
      {:ok, team_membership} ->
        redirect_target =
          if team_membership.user_id == current_user.id and team_membership.role == :viewer do
            Routes.site_path(conn, :index)
          else
            Routes.settings_path(conn, :team_general)
          end

        conn
        |> put_flash(
          :success,
          "#{team_membership.user.name} is now #{PlausibleWeb.SiteView.with_indefinite_article(to_string(team_membership.role))}"
        )
        |> redirect(to: redirect_target)

      {:error, :only_one_owner} ->
        conn
        |> put_flash(
          :error,
          "#{team_membership.user.name} is the only owner and can't be changed"
        )
        |> redirect(to: Routes.settings_path(conn, :team_general))

      {:error, _} ->
        conn
        |> put_flash(:error, "You are not allowed to grant the #{new_role_str} role")
        |> redirect(to: Routes.settings_path(conn, :team_general))
    end
  end

  def remove_member(conn, %{"id" => user_id}) do
    %{my_team: team, current_user: current_user} = conn

    case Teams.Memberships.Remove.remove(team, user_id, current_user) do
      {:ok, _team_membership} ->
        redirect_target =
          if user_id == current_user.id do
            Routes.site_path(conn, :index)
          else
            Routes.settings_path(conn, :team_general)
          end

        conn
        |> put_flash(:success, "User has been removed from \"#{team.name}\" team")
        |> redirect(external: redirect_target)

      {:error, :member_not_found} ->
        conn
        |> put_flash(:success, "User has been removed from \"#{team.name}\" team")
        |> redirect(external: Routes.settings_path(conn, :team_general))

      {:error, :permission_denied} ->
        conn
        |> put_flash(:error, "You are not allowed to remove that member")
        |> redirect(to: Routes.settings_path(conn, :team_general))
    end
  end
end
