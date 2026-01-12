defmodule PlausibleWeb.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller

  def render_error(conn, status, message) do
    conn
    |> put_status(status)
    |> put_view(PlausibleWeb.ErrorView)
    |> render("#{status}.html", message: message, layout: error_layout())
  end

  def render_error(conn, status) do
    conn
    |> put_status(status)
    |> put_view(PlausibleWeb.ErrorView)
    |> render("#{status}.html", layout: error_layout())
  end

  defp error_layout,
    do: Application.get_env(:plausible, PlausibleWeb.Endpoint)[:render_errors][:layout]

  def debug_metadata(conn) do
    %{
      request_method: conn.method,
      request_path: conn.request_path,
      params: conn.params,
      phoenix_controller: conn.private.phoenix_controller |> to_string(),
      phoenix_action: conn.private.phoenix_action |> to_string(),
      site_id: conn.assigns.site.id,
      site_domain: conn.assigns.site.domain,
      user_id: get_user_id(conn, conn.assigns),
      team_id: get_team_id(conn, conn.assigns)
    }
  end

  defp get_user_id(_conn, %{current_user: user}), do: user.id

  defp get_user_id(conn, _assigns) do
    case PlausibleWeb.UserAuth.get_user_session(conn) do
      {:ok, user_session} -> user_session.user_id
      _ -> nil
    end
  end

  defp get_team_id(_conn, %{current_team: %Plausible.Teams.Team{id: id}}), do: id
  defp get_team_id(_conn, %{site_team: %Plausible.Teams.Team{id: id}}), do: id
  defp get_team_id(_conn, %{api_context: :site, site: %Plausible.Site{team_id: id}}), do: id
  defp get_team_id(_conn, _assigns), do: nil
end
