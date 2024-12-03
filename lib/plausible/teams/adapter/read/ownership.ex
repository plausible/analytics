defmodule Plausible.Teams.Adapter.Read.Ownership do
  @moduledoc """
  Transition adapter for new schema reads
  """
  use Plausible
  use Plausible.Teams.Adapter
  alias Plausible.Site
  alias Plausible.Auth

  def all_pending_site_transfers(email, user) do
    switch(user,
      team_fn: fn _ -> Plausible.Teams.Memberships.all_pending_site_transfers(email) end,
      user_fn: fn _ -> Plausible.Site.Memberships.all_pending_ownerships(email) end
    )
  end

  def get_owner(site, user) do
    switch(user,
      team_fn: fn team ->
        case Teams.Sites.get_owner(team) do
          {:ok, user} -> user
          _ -> nil
        end
      end,
      user_fn: fn _ ->
        Plausible.Repo.preload(site, :owner).owner
      end
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
      missing_features =
        Plausible.Billing.Quota.Usage.features_usage(nil, [site.id])
        |> Enum.filter(&(&1.check_availability(new_owner) != :ok))

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
