defmodule Plausible.Site.Memberships.AcceptInvitation do
  use Plausible

  @moduledoc """
  Service for accepting invitations, including ownership transfers.

  Accepting invitation accounts for the fact that it's possible
  that accepting user has an existing membership for the site and
  acts permissively to not unnecessarily disrupt the flow while
  also maintaining integrity of site memberships. This also applies
  to cases where users update their email address between issuing
  the invitation and accepting it.
  """

  alias Ecto.Multi
  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Site.Memberships.Invitations

  require Logger

  @type transfer_error() ::
          Billing.Quota.Limits.over_limits_error()
          | Ecto.Changeset.t()
          | :transfer_to_self
          | :no_plan

  @type accept_error() ::
          :invitation_not_found
          | Billing.Quota.Limits.over_limits_error()
          | Ecto.Changeset.t()
          | :no_plan

  @spec bulk_transfer_ownership_direct(Auth.User.t(), [Site.t()], Auth.User.t()) ::
          {:ok, [Site.Membership.t()]} | {:error, transfer_error()}
  def bulk_transfer_ownership_direct(current_user, sites, new_owner) do
    Repo.transaction(fn ->
      for site <- sites do
        case transfer_ownership(current_user, site, new_owner) do
          {:ok, membership} ->
            membership

          {:error, error} ->
            Repo.rollback(error)
        end
      end
    end)
  end

  @spec accept_invitation(String.t(), Auth.User.t()) ::
          {:ok, Site.Membership.t()} | {:error, accept_error()}
  def accept_invitation(invitation_id, user) do
    with {:ok, invitation} <- Invitations.find_for_user(invitation_id, user) do
      if invitation.role == :owner do
        do_accept_ownership_transfer(invitation, user)
      else
        do_accept_invitation(invitation, user)
      end
    end
  end

  defp transfer_ownership(current_user, site, new_owner) do
    with :ok <-
           Plausible.Teams.Adapter.Read.Invitations.ensure_transfer_valid(
             current_user,
             site,
             new_owner,
             :owner
           ),
         :ok <- Plausible.Teams.Adapter.Read.Ownership.ensure_can_take_ownership(site, new_owner) do
      membership = get_or_create_owner_membership(site, new_owner)

      multi = add_and_transfer_ownership(site, membership, new_owner)

      case Repo.transaction(multi) do
        {:ok, changes} ->
          Plausible.Teams.Invitations.transfer_site_sync(site, new_owner)

          membership = Repo.preload(changes.membership, [:site, :user])

          {:ok, membership}

        {:error, _operation, error, _changes} ->
          {:error, error}
      end
    end
  end

  defp do_accept_ownership_transfer(invitation, user) do
    membership = get_or_create_membership(invitation, user)
    site = invitation.site

    with :ok <-
           Plausible.Teams.Adapter.Read.Invitations.ensure_transfer_valid(
             user,
             site,
             user,
             :owner
           ),
         :ok <- Plausible.Teams.Adapter.Read.Ownership.ensure_can_take_ownership(site, user) do
      site
      |> add_and_transfer_ownership(membership, user)
      |> Multi.delete(:invitation, invitation)
      |> Multi.run(:sync_transfer, fn _repo, _context ->
        Plausible.Teams.Invitations.accept_transfer_sync(invitation, user)
        {:ok, nil}
      end)
      |> finalize_invitation(invitation)
    end
  end

  defp do_accept_invitation(invitation, user) do
    membership = get_or_create_membership(invitation, user)

    invitation
    |> add(membership, user)
    |> Multi.run(:sync_invitation, fn _repo, _context ->
      Plausible.Teams.Invitations.accept_invitation_sync(invitation, user)
      {:ok, nil}
    end)
    |> finalize_invitation(invitation)
  end

  defp finalize_invitation(multi, invitation) do
    case Repo.transaction(multi) do
      {:ok, changes} ->
        notify_invitation_accepted(invitation)

        membership = Repo.preload(changes.membership, [:site, :user])

        {:ok, membership}

      {:error, _operation, error, _changes} ->
        {:error, error}
    end
  end

  defp add_and_transfer_ownership(site, membership, user) do
    Multi.new()
    |> downgrade_previous_owner(site, user)
    |> Multi.insert_or_update(:membership, membership)
    |> Multi.run(:update_locked_sites, fn _, _ ->
      on_ee do
        # At this point this function should be guaranteed to unlock
        # the site, via `Invitations.ensure_can_take_ownership/2`.
        :unlocked = Billing.SiteLocker.update_sites_for(user, send_email?: false)
      end

      {:ok, :unlocked}
    end)
  end

  # If there's an existing membership, we DO NOT change the role
  # to avoid accidental role downgrade.
  defp add(invitation, membership, _user) do
    if membership.data.id do
      Multi.new()
      |> Multi.put(:membership, membership.data)
      |> Multi.delete(:invitation, invitation)
    else
      Multi.new()
      |> Multi.insert(:membership, membership)
      |> Multi.delete(:invitation, invitation)
    end
  end

  defp get_or_create_membership(invitation, user) do
    case Repo.get_by(Site.Membership, user_id: user.id, site_id: invitation.site.id) do
      nil -> Site.Membership.new(invitation.site, user)
      membership -> membership
    end
    |> Site.Membership.set_role(invitation.role)
  end

  defp get_or_create_owner_membership(site, user) do
    case Repo.get_by(Site.Membership, user_id: user.id, site_id: site.id) do
      nil -> Site.Membership.new(site, user)
      membership -> membership
    end
    |> Site.Membership.set_role(:owner)
  end

  # If the new owner is the same as old owner, we do not downgrade them
  # to avoid leaving site without an owner!
  defp downgrade_previous_owner(multi, site, new_owner) do
    new_owner_id = new_owner.id

    previous_owner = get_previous_owner(site)

    case previous_owner do
      %{user_id: ^new_owner_id} ->
        Multi.put(multi, :previous_owner_membership, previous_owner)

      nil ->
        Logger.warning(
          "Transferring ownership from a site with no owner: #{site.domain} " <>
            ", new owner ID: #{new_owner_id}"
        )

        Multi.put(multi, :previous_owner_membership, nil)

      previous_owner ->
        Multi.insert_or_update(
          multi,
          :previous_owner_membership,
          Site.Membership.set_role(previous_owner, :admin)
        )
    end
  end

  defp get_previous_owner(site) do
    # Disguise new team schema, as old site membership,
    # so that we can keep switching on reads
    case Plausible.Teams.Sites.get_owner(site.team) do
      {:ok, user} ->
        %Site.Membership{site_id: site.id, user_id: user.id}

      _ ->
        nil
    end
  end

  defp notify_invitation_accepted(%Auth.Invitation{role: :owner} = invitation) do
    PlausibleWeb.Email.ownership_transfer_accepted(
      invitation.email,
      invitation.inviter.email,
      invitation.site
    )
    |> Plausible.Mailer.send()
  end

  defp notify_invitation_accepted(invitation) do
    invitation.inviter.email
    |> PlausibleWeb.Email.invitation_accepted(invitation.email, invitation.site)
    |> Plausible.Mailer.send()
  end
end
