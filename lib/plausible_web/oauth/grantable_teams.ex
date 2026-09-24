defmodule PlausibleWeb.OAuth.GrantableTeams do
  @moduledoc """
  The teams an authorization request may bind a grant to.

  `current_team` is deliberately not consulted: on the authorize route the URL
  is authored by the client, so the ambient team is attacker-influenced. The
  teams offered on the consent screen are the only ones a grant can bind to.

  Both the controller that renders the screen and the LiveView that takes the
  decision resolve the team the same way, from their own assigns.
  """

  alias Plausible.Teams.Team

  @doc """
  Lists the teams the given assigns may grant access to, preferred first.
  """
  @spec list(map()) :: [Team.t()]
  def list(assigns) do
    case assigns[:my_team] do
      nil -> assigns[:teams] || []
      my_team -> [my_team | assigns[:teams] || []]
    end
  end

  @doc """
  Resolves `identifier` against the grantable teams, falling back to the first.

  An identifier naming a team the user cannot grant is ignored rather than
  refused, since it arrives in a client-authored URL.
  """
  @spec resolve(map(), String.t() | nil) :: Team.t() | nil
  def resolve(assigns, identifier) do
    teams = list(assigns)

    Enum.find(teams, &(&1.identifier == identifier)) || List.first(teams)
  end
end
