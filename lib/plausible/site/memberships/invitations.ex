defmodule Plausible.Site.Memberships.Invitations do
  @moduledoc false

  import Ecto.Query, only: [from: 2]

  alias Plausible.Site
  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Billing.Quota
  alias Plausible.Billing.Feature

  @type missing_features_error() :: {:missing_features, [Feature.t()]}

  @spec find_for_user(String.t(), Auth.User.t()) ::
          {:ok, Auth.Invitation.t()} | {:error, :invitation_not_found}
  def find_for_user(invitation_id, user) do
    invitation =
      Auth.Invitation
      |> Repo.get_by(invitation_id: invitation_id, email: user.email)
      |> Repo.preload([:site, :inviter])

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end

  @spec find_for_site(String.t(), Plausible.Site.t()) ::
          {:ok, Auth.Invitation.t()} | {:error, :invitation_not_found}
  def find_for_site(invitation_id, site) do
    invitation =
      Auth.Invitation
      |> Repo.get_by(invitation_id: invitation_id, site_id: site.id)
      |> Repo.preload([:site, :inviter])

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end

  @spec delete_invitation(Auth.Invitation.t()) :: :ok
  def delete_invitation(invitation) do
    Repo.delete_all(from(i in Auth.Invitation, where: i.id == ^invitation.id))

    :ok
  end

  @spec ensure_can_take_ownership(Site.t(), Auth.User.t()) ::
          :ok | {:error, Quota.over_limits_error() | missing_features_error()}
  def ensure_can_take_ownership(site, new_owner) do
    site = Repo.preload(site, :owner)
    new_owner = Plausible.Users.with_subscription(new_owner)
    plan = Plausible.Billing.Plans.get_subscription_plan(new_owner.subscription)

    if is_nil(plan) || plan == :free_10k do
      # TODO:
      # We probably want to change this behaviour and block all ownership transfers
      # to accounts that don't have a real subscription. In this commit, the :ok on
      # the next line is ignoring that to keep the tests passing.
      :ok
    else
      usage_after_transfer = %{
        monthly_pageviews: monthly_pageview_usage_after_transfer(site, new_owner),
        team_members: team_member_usage_after_transfer(site, new_owner),
        sites: Quota.site_usage(new_owner) + 1
      }

      with :ok <- Quota.ensure_within_plan_limits(new_owner, plan, usage_after_transfer) do
        ensure_feature_access(site, new_owner)
      end
    end
  end

  defp team_member_usage_after_transfer(site, new_owner) do
    current_usage = Quota.team_member_usage(new_owner)
    site_usage = Repo.aggregate(Quota.team_member_usage_query(site.owner, site), :count)

    extra_usage =
      if Plausible.Sites.is_member?(new_owner.id, site), do: 0, else: 1

    current_usage + site_usage + extra_usage
  end

  def monthly_pageview_usage_after_transfer(site, new_owner) do
    site_ids = Plausible.Sites.owned_site_ids(new_owner) ++ [site.id]
    Quota.monthly_pageview_usage(new_owner, site_ids)
  end

  defp ensure_feature_access(site, new_owner) do
    missing_features =
      site
      |> Quota.features_usage()
      |> Enum.filter(&(&1.check_availability(new_owner) != :ok))

    if missing_features == [] do
      :ok
    else
      {:error, {:missing_features, missing_features}}
    end
  end
end
