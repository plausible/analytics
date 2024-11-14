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

  def site_limit(user) do
    if Teams.read_team_schemas?(user) do
      team =
        case Teams.get_by_owner(user) do
          {:ok, team} -> team
          {:error, _} -> nil
        end

      Teams.Billing.site_limit(team)
    else
      Plausible.Billing.Quota.Limits.site_limit(user)
    end
  end

  def ensure_can_add_new_site(user) do
    if Teams.read_team_schemas?(user) do
      team =
        case Teams.get_by_owner(user) do
          {:ok, team} -> team
          {:error, _} -> nil
        end

      Teams.Billing.ensure_can_add_new_site(team)
    else
      Plausible.Billing.Quota.ensure_can_add_new_site(user)
    end
  end

  def site_usage(user) do
    if Teams.read_team_schemas?(user) do
      team =
        case Teams.get_by_owner(user) do
          {:ok, team} -> team
          {:error, _} -> nil
        end

      Teams.Billing.site_usage(team)
    else
      Plausible.Billing.Quota.Usage.site_usage(user)
    end
  end
end
