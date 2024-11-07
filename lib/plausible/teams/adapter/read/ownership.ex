defmodule Plausible.Teams.Adapter.Read.Ownership do
  @moduledoc """
  Transition adapter for new schema reads 
  """
  use Plausible
  alias Plausible.Site
  alias Plausible.Auth
  alias Plausible.Teams
  alias Plausible.Site.Memberships.Invitations

  def ensure_can_take_ownership(site, user) do
    if Teams.read_team_schemas?(user) do
      team =
        case Teams.get_by_owner(user) do
          {:ok, team} -> team
          {:error, _} -> nil
        end

      Teams.Invitations.ensure_can_take_ownership(site, team)
    else
      Invitations.ensure_can_take_ownership(site, user)
    end
  end

  def has_sites?(user) do
    if Teams.read_team_schemas?(user) do
      Teams.Users.has_sites?(user, include_pending?: true)
    else
      Site.Memberships.any_or_pending?(user)
    end
  end

  def owns_sites?(user, sites) do
    if Teams.read_team_schemas?(user) do
      Teams.Users.owns_sites?(user, include_pending?: true)
    else
      Enum.any?(sites.entries, fn site ->
        length(site.invitations) > 0 && List.first(site.invitations).role == :owner
      end) ||
        Auth.user_owns_sites?(user)
    end
  end

  on_ee do
    def check_feature_access(site, new_owner) do
      user_or_team =
        if Teams.read_team_schemas?(new_owner) do
          case Teams.get_by_owner(new_owner) do
            {:ok, team} -> team
            {:error, _} -> nil
          end
        else
          new_owner
        end

      missing_features =
        Plausible.Billing.Quota.Usage.features_usage(nil, [site.id])
        |> Enum.filter(&(&1.check_availability(user_or_team) != :ok))

      if missing_features == [] do
        :ok
      else
        {:error, {:missing_features, missing_features}}
      end
    end
  else
    def check_feature_access(_site, _new_owner) do
      :ok
    end
  end
end
