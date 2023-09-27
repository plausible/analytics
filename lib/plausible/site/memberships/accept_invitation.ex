defmodule Plausible.Site.Memberships.AcceptInvitation do
  @moduledoc """
  Service for accepting invitations, including ownership transfers
  """

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Site

  def accept_invitation(invitation_id, user) do
    with {:ok, invitation} <- find_invitation(invitation_id) do
      membership = get_or_create_membership(invitation, user)

      multi =
        Multi.new()
        |> maybe_prepare_ownership_transfer(invitation, user)
        |> Multi.insert_or_update(:membership, membership)
        |> Multi.delete(:invitation, invitation)
        |> Multi.run(:site_locker, fn _, %{user: updated_user} ->
          {:ok,
           Billing.SiteLocker.check_sites_for(Repo.reload!(updated_user), send_email?: false)}
        end)

      case Repo.transaction(multi) do
        {:ok, changes} ->
          if changes.site_locker == {:locked, :grace_period_ended_now} do
            Billing.SiteLocker.send_grace_period_end_email(changes.user)
          end

          notify_invitation_accepted(invitation)

          membership = Repo.preload(changes.membership, [:site, :user])

          {:ok, membership}

        {:error, _operation, error, _changes} ->
          {:error, error}
      end
    end
  end

  defp get_or_create_membership(invitation, user) do
    case Repo.get_by(Site.Membership, user_id: user.id, site_id: invitation.site.id) do
      nil -> Site.Membership.new(invitation.site, user)
      membership -> membership
    end
    |> Site.Membership.set_role(invitation.role)
  end

  defp maybe_prepare_ownership_transfer(multi, %{role: :owner} = invitation, user) do
    multi
    |> downgrade_previous_owner(invitation.site)
    |> maybe_end_trial_of_new_owner(user)
  end

  defp maybe_prepare_ownership_transfer(multi, _invitation, user),
    do: Multi.put(multi, :user, user)

  defp downgrade_previous_owner(multi, site) do
    previous_owner =
      from(
        sm in Site.Membership,
        where: sm.site_id == ^site.id,
        where: sm.role == :owner
      )

    Multi.update_all(multi, :previous_owner, previous_owner, set: [role: :admin])
  end

  defp maybe_end_trial_of_new_owner(multi, new_owner) do
    if Application.get_env(:plausible, :is_selfhost) do
      Multi.put(multi, :user, new_owner)
    else
      end_trial_of_new_owner(multi, new_owner)
    end
  end

  defp end_trial_of_new_owner(multi, new_owner) do
    if Billing.on_trial?(new_owner) || is_nil(new_owner.trial_expiry_date) do
      Multi.update(multi, :user, Auth.User.end_trial(new_owner))
    else
      Multi.put(multi, :user, new_owner)
    end
  end

  defp find_invitation(invitation_id) do
    invitation =
      Auth.Invitation
      |> Repo.get_by(invitation_id: invitation_id)
      |> Repo.preload([:site, :inviter])

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end

  defp notify_invitation_accepted(%Auth.Invitation{role: :owner} = invitation) do
    PlausibleWeb.Email.ownership_transfer_accepted(invitation)
    |> Plausible.Mailer.send()
  end

  defp notify_invitation_accepted(invitation) do
    PlausibleWeb.Email.invitation_accepted(invitation)
    |> Plausible.Mailer.send()
  end
end
