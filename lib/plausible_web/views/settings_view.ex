defmodule PlausibleWeb.SettingsView do
  use PlausibleWeb, :view
  use Plausible

  alias Plausible.Teams

  def owned_by(team) do
    if Teams.setup?(team) do
      Teams.name(team)
    else
      case team.owners do
        [owner | _] -> "Owned by #{owner.name}"
        [] -> ""
      end
    end
  end
end
