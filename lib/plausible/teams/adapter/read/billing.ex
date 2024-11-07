defmodule Plausible.Teams.Adapter.Read.Billing do
  @moduledoc """
  Transition adapter for new schema reads 
  """
  alias Plausible.Teams

  def check_needs_to_upgrade(user) do
    if Teams.read_team_schemas?(user) do
      team =
        case Teams.get_by_owner(user) do
          {:ok, team} -> team
          {:error, _} -> nil
        end

      Teams.Billing.check_needs_to_upgrade(team)
    else
      Plausible.Billing.check_needs_to_upgrade(user)
    end
  end
end
