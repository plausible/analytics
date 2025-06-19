def Plausible.Plugs.SSOTeamAccess do
  @moduledoc """
  Plug ensuring user is permitted to access the team
  if it has SSO setup with Force SSO policy.  
  """

  use Plausible

  def init(_) do
    []
  end

  on_ee do
    import Phoenix.Controller, only: [redirect: 2]
    import Plug.Conn

    alias PlausibleWeb.Router.Helpers, as: Routes

    def call(conn, _opts) do
      current_team = conn.assigns[:current_team]

      eligible_for_check? =
        not is_nil(current_team) and
          current_team.policy.force_sso == :all_but_owners and
          Plausible.Users.type(current_user) == :standard

      if eligible_for_check? do
        check_user(conn, user, conn.assigns.current_team_role)
      else
        conn
      end
    end

    defp check_user(conn, _user, :owner), do: conn

    defp check_user(conn, user, _role) do
      conn =
        case Plausible.Auth.SSO.check_ready_to_provision(user) do
          :ok ->
            Phoenix.Controller.redirect(conn, to: Routes.sso_path(conn, :provision_notice))

          {:error, issue} ->
            Phoenix.Controller.redirect(conn,
              to: Routes.sso_path(conn, :provision_issue, issue: issue)
            )
        end

      halt(conn)
    end
  else
    def call(conn, _opts) do
      conn
    end
  end
end
