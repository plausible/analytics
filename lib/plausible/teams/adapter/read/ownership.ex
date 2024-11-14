defmodule Plausible.Teams.Adapter.Read.Ownership do
  @moduledoc """
  Transition adapter for new schema reads 
  """
  use Plausible
  use Plausible.Teams.Adapter
  alias Plausible.Site
  alias Plausible.Auth
  alias Plausible.Site.Memberships.Invitations

  def ensure_can_take_ownership(site, user) do
    switch(
      user,
      team_fn: &Teams.Invitations.ensure_can_take_ownership(site, &1),
      user_fn: &Invitations.ensure_can_take_ownership(site, &1)
    )
  end

  def has_sites?(user) do
    switch(
      user,
      team_fn: fn _ -> Teams.Users.has_sites?(user, include_pending?: true) end,
      user_fn: &Site.Memberships.any_or_pending?/1
    )
  end

  def owns_sites?(user, sites) do
    switch(
      user,
      team_fn: fn _ -> Teams.Users.owns_sites?(user, include_pending?: true) end,
      user_fn: fn user ->
        Enum.any?(sites.entries, fn site ->
          length(site.invitations) > 0 && List.first(site.invitations).role == :owner
        end) ||
          Auth.user_owns_sites?(user)
      end
    )
  end

  on_ee do
    def check_feature_access(site, new_owner) do
      team_or_user = team_or_user(new_owner)

      missing_features =
        Plausible.Billing.Quota.Usage.features_usage(nil, [site.id])
        |> Enum.filter(&(&1.check_availability(team_or_user) != :ok))

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
