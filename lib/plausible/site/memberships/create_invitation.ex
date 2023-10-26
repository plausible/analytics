defmodule Plausible.Site.Memberships.CreateInvitation do
  @moduledoc """
  Service for inviting new or existing users to a sites, including ownershhip
  transfers.
  """

  alias Plausible.Auth.{User, Invitation}
  alias Plausible.{Site, Sites, Site.Membership}
  alias Plausible.Billing.Quota
  import Ecto.Query

  @type invite_error() ::
          Ecto.Changeset.t()
          | :already_a_member
          | :transfer_to_self
          | {:over_limit, non_neg_integer()}
          | :forbidden
          | :upgrade_required

  @spec create_invitation(Site.t(), User.t(), String.t(), atom()) ::
          {:ok, Invitation.t()} | {:error, invite_error()}
  @doc """
  Invites a new team member to the given site. Returns a
  %Plausible.Auth.Invitation{} struct and sends the invitee an email to accept
  this invitation.

  The inviter must have enough permissions to invite the new team member,
  otherwise this function returns `{:error, :forbidden}`.

  If the new team member role is `:owner`, this function handles the invitation
  as an ownership transfer and requires the inviter to be the owner of the site.
  """
  def create_invitation(site, inviter, invitee_email, role) do
    Plausible.Repo.transaction(fn ->
      do_invite(site, inviter, invitee_email, role)
    end)
  end

  @spec bulk_transfer_ownership_direct([Site.t()], User.t()) ::
          {:ok, [Membership.t()]} | {:error, invite_error()}
  def bulk_transfer_ownership_direct(sites, new_owner) do
    Plausible.Repo.transaction(fn ->
      for site <- sites do
        with site <- Plausible.Repo.preload(site, :owner),
             :ok <- ensure_transfer_valid(site, new_owner, :owner),
             {:ok, membership} <- Site.Memberships.transfer_ownership(site, new_owner) do
          membership
        else
          {:error, error} -> Plausible.Repo.rollback(error)
        end
      end
    end)
  end

  @spec bulk_create_invitation([Site.t()], User.t(), String.t(), atom(), Keyword.t()) ::
          {:ok, [Invitation.t()]} | {:error, invite_error()}
  def bulk_create_invitation(sites, inviter, invitee_email, role, opts \\ []) do
    Plausible.Repo.transaction(fn ->
      for site <- sites do
        do_invite(site, inviter, invitee_email, role, opts)
      end
    end)
  end

  defp do_invite(site, inviter, invitee_email, role, opts \\ []) do
    attrs = %{email: invitee_email, role: role, site_id: site.id, inviter_id: inviter.id}

    with site <- Plausible.Repo.preload(site, :owner),
         :ok <- check_invitation_permissions(site, inviter, role, opts),
         :ok <- check_team_member_limit(site, role),
         invitee <- Plausible.Auth.find_user_by(email: invitee_email),
         :ok <- ensure_transfer_valid(site, invitee, role),
         :ok <- ensure_new_membership(site, invitee, role),
         %Ecto.Changeset{} = changeset <- Invitation.new(attrs),
         {:ok, invitation} <- Plausible.Repo.insert(changeset) do
      send_invitation_email(invitation, invitee)
      invitation
    else
      {:error, cause} -> Plausible.Repo.rollback(cause)
    end
  end

  defp check_invitation_permissions(site, inviter, requested_role, opts) do
    check_permissions? = Keyword.get(opts, :check_permissions, true)

    if check_permissions? do
      required_roles = if requested_role == :owner, do: [:owner], else: [:admin, :owner]

      membership_query =
        from(m in Membership,
          where: m.user_id == ^inviter.id and m.site_id == ^site.id and m.role in ^required_roles
        )

      if Plausible.Repo.exists?(membership_query), do: :ok, else: {:error, :forbidden}
    else
      :ok
    end
  end

  defp send_invitation_email(invitation, invitee) do
    invitation = Plausible.Repo.preload(invitation, [:site, :inviter])

    email =
      case {invitee, invitation.role} do
        {invitee, :owner} -> PlausibleWeb.Email.ownership_transfer_request(invitation, invitee)
        {nil, _role} -> PlausibleWeb.Email.new_user_invitation(invitation)
        {%User{}, _role} -> PlausibleWeb.Email.existing_user_invitation(invitation)
      end

    Plausible.Mailer.send(email)
  end

  defp within_team_member_limit_after_transfer?(site, new_owner) do
    limit = Quota.team_member_limit(new_owner)

    current_usage = Quota.team_member_usage(new_owner)
    site_usage = Plausible.Repo.aggregate(Quota.team_member_usage_query(site.owner, site), :count)
    usage_after_transfer = current_usage + site_usage

    Quota.within_limit?(usage_after_transfer, limit)
  end

  defp within_site_limit_after_transfer?(new_owner) do
    limit = Quota.site_limit(new_owner)
    usage_after_transfer = Quota.site_usage(new_owner) + 1

    Quota.within_limit?(usage_after_transfer, limit)
  end

  defp has_access_to_site_features?(site, new_owner) do
    features_to_check = [
      Plausible.Billing.Feature.Props,
      Plausible.Billing.Feature.RevenueGoals,
      Plausible.Billing.Feature.Funnels
    ]

    Enum.all?(features_to_check, fn feature ->
      if feature.enabled?(site), do: feature.check_availability(new_owner) == :ok, else: true
    end)
  end

  defp ensure_transfer_valid(%Site{} = site, %User{} = new_owner, :owner) do
    cond do
      Sites.role(new_owner.id, site) == :owner -> {:error, :transfer_to_self}
      not within_team_member_limit_after_transfer?(site, new_owner) -> {:error, :upgrade_required}
      not within_site_limit_after_transfer?(new_owner) -> {:error, :upgrade_required}
      not has_access_to_site_features?(site, new_owner) -> {:error, :upgrade_required}
      true -> :ok
    end
  end

  defp ensure_transfer_valid(_site, _invitee, _role) do
    :ok
  end

  defp ensure_new_membership(_site, _invitee, :owner) do
    :ok
  end

  defp ensure_new_membership(site, invitee, _role) do
    if invitee && Sites.is_member?(invitee.id, site) do
      {:error, :already_a_member}
    else
      :ok
    end
  end

  defp check_team_member_limit(_site, :owner) do
    :ok
  end

  defp check_team_member_limit(site, _role) do
    site = Plausible.Repo.preload(site, :owner)
    limit = Quota.team_member_limit(site.owner)
    usage = Quota.team_member_usage(site.owner)

    if Quota.within_limit?(usage, limit),
      do: :ok,
      else: {:error, {:over_limit, limit}}
  end
end
