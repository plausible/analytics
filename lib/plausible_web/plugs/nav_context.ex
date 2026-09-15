defmodule PlausibleWeb.Plugs.NavContext do
  @moduledoc """
  Populates conn assigns with the data the breadcrumb nav needs on top of what
  `PlausibleWeb.AuthPlug` already provides: the switchable site list, and the
  plan and member counts shown in the team switcher.

  The root layout renders on the dead render for LiveViews too, so these assigns
  reach the header on every browser page.
  """

  import Plug.Conn

  alias Plausible.Auth
  alias Plausible.Teams

  def init(opts), do: opts

  def call(%{assigns: %{current_user: %Auth.User{} = user}} = conn, _opts) do
    teams =
      [conn.assigns[:current_team], conn.assigns[:my_team] | conn.assigns[:teams] || []]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.id)

    nav_sites =
      Teams.Sites.list_for_switcher(user, conn.assigns[:current_team],
        include_consolidated?: true
      )

    conn
    |> assign(:nav_sites, nav_sites)
    |> assign(:nav_team_meta, Teams.nav_meta(teams))
  end

  def call(conn, _opts) do
    conn
    |> assign(:nav_sites, [])
    |> assign(:nav_team_meta, %{})
  end
end
