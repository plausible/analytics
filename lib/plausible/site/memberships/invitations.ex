defmodule Plausible.Site.Memberships.Invitations do
  @moduledoc false

  use Plausible

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

  @spec ensure_transfer_valid(Site.t(), Auth.User.t() | nil, Site.Membership.role()) ::
          :ok | {:error, :transfer_to_self}
  def ensure_transfer_valid(%Site{} = site, %Auth.User{} = new_owner, :owner) do
    if Plausible.Sites.role(new_owner.id, site) == :owner do
      {:error, :transfer_to_self}
    else
      :ok
    end
  end

  def ensure_transfer_valid(_site, _invitee, _role) do
    :ok
  end

  on_full_build do
    @spec ensure_can_take_ownership(Site.t(), Auth.User.t()) ::
            :ok | {:error, Quota.over_limits_error() | :no_plan}
    def ensure_can_take_ownership(site, new_owner) do
      site = Repo.preload(site, :owner)
      new_owner = Plausible.Users.with_subscription(new_owner)
      plan = Plausible.Billing.Plans.get_subscription_plan(new_owner.subscription)

      active_subscription? = Plausible.Billing.subscription_is_active?(new_owner.subscription)

      if active_subscription? && plan != :free_10k do
        usage_after_transfer = %{
          monthly_pageviews: monthly_pageview_usage_after_transfer(site, new_owner),
          team_members: team_member_usage_after_transfer(site, new_owner),
          sites: Quota.site_usage(new_owner) + 1
        }

        Quota.ensure_within_plan_limits(usage_after_transfer, plan)
      else
        {:error, :no_plan}
      end
    end

    defp team_member_usage_after_transfer(site, new_owner) do
      current_usage = Quota.team_member_usage(new_owner)
      site_usage = Repo.aggregate(Quota.team_member_usage_query(site.owner, site), :count)

      extra_usage =
        if Plausible.Sites.is_member?(new_owner.id, site), do: 0, else: 1

      current_usage + site_usage + extra_usage
    end

    defp monthly_pageview_usage_after_transfer(site, new_owner) do
      site_ids = Plausible.Sites.owned_site_ids(new_owner) ++ [site.id]
      Quota.monthly_pageview_usage(new_owner, site_ids)
    end
  else
    @spec ensure_can_take_ownership(Site.t(), Auth.User.t()) :: :ok
    def ensure_can_take_ownership(_site, _new_owner) do
      :ok
    end
  end

  @spec check_feature_access(Site.t(), Auth.User.t(), boolean()) ::
          :ok | {:error, missing_features_error()}
  def check_feature_access(_site, _new_owner, true = _selfhost?) do
    :ok
  end

  def check_feature_access(site, new_owner, false = _selfhost?) do
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
