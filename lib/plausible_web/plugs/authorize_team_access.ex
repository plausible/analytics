defmodule Plausible.Plugs.AuthorizeTeamAccess do
  @moduledoc """
  Enforce team role to be within the declared set.
  `:current_team_role` is assumed to be populated by `PlausibleWeb.AuthPlug`.

  For cases where no `:current_team` exists, the plug is permissive,
  so that existing notices can be displayed still.
  """

  alias PlausibleWeb.Router.Helpers, as: Routes

  import Plug.Conn

  @all_roles Plausible.Teams.Membership.roles() -- [:guest]

  def init([]), do: @all_roles

  def init(roles) when is_list(roles) do
    true = Enum.all?(roles, &(&1 in @all_roles))
    roles
  end

  def call(conn, roles \\ @all_roles) do
    current_team = conn.assigns[:current_team]

    if current_team && Plausible.Teams.enabled?(current_team) do
      current_team_role = conn.assigns[:current_team_role]

      if current_team_role in roles do
        conn
      else
        conn
        |> Phoenix.Controller.redirect(to: Routes.site_path(conn, :index))
        |> halt()
      end
    else
      conn
    end
  end
end
