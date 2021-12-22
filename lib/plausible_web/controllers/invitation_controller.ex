defmodule PlausibleWeb.InvitationController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Ecto.Multi
  alias Plausible.Auth.Invitation
  alias Plausible.Site.Membership

  plug PlausibleWeb.RequireAccountPlug

  def accept_invitation(conn, %{"invitation_id" => invitation_id}) do
    invitation =
      Repo.get_by!(Invitation, invitation_id: invitation_id)
      |> Repo.preload([:site, :inviter])

    user = conn.assigns[:current_user]
    existing_membership = Repo.get_by(Membership, user_id: user.id, site_id: invitation.site.id)

    multi =
      if invitation.role == :owner do
        Multi.new()
        |> downgrade_previous_owner(invitation.site)
        |> maybe_end_trial_of_new_owner(user)
      else
        Multi.new()
      end

    membership_changeset =
      Membership.changeset(existing_membership || %Membership{}, %{
        user_id: user.id,
        site_id: invitation.site.id,
        role: invitation.role
      })

    multi =
      multi
      |> Multi.insert_or_update(:membership, membership_changeset)
      |> Multi.delete(:invitation, invitation)

    case Repo.transaction(multi) do
      {:ok, changes} ->
        updated_user = Map.get(changes, :user, user)
        notify_invitation_accepted(invitation)
        Plausible.Billing.SiteLocker.check_sites_for(updated_user)

        conn
        |> put_flash(:success, "You now have access to #{invitation.site.domain}")
        |> redirect(to: "/#{URI.encode_www_form(invitation.site.domain)}")

      {:error, _} ->
        conn
        |> put_flash(:error, "Something went wrong, please try again")
        |> redirect(to: "/sites")
    end
  end

  defp downgrade_previous_owner(multi, site) do
    prev_owner =
      from(
        sm in Plausible.Site.Membership,
        where: sm.site_id == ^site.id,
        where: sm.role == :owner
      )

    Multi.update_all(multi, :prev_owner, prev_owner, set: [role: :admin])
  end

  defp maybe_end_trial_of_new_owner(multi, new_owner) do
    if !Application.get_env(:plausible, :is_selfhost) do
      end_trial_of_new_owner(multi, new_owner)
    end
  end

  defp end_trial_of_new_owner(multi, new_owner) do
    if Plausible.Billing.on_trial?(new_owner) || is_nil(new_owner.trial_expiry_date) do
      Ecto.Multi.update(multi, :user, Plausible.Auth.User.end_trial(new_owner))
    else
      multi
    end
  end

  def reject_invitation(conn, %{"invitation_id" => invitation_id}) do
    invitation =
      Repo.get_by!(Invitation, invitation_id: invitation_id)
      |> Repo.preload([:site, :inviter])

    Repo.delete!(invitation)
    notify_invitation_rejected(invitation)

    conn
    |> put_flash(:success, "You have rejected the invitation to #{invitation.site.domain}")
    |> redirect(to: "/sites")
  end

  defp notify_invitation_accepted(%Invitation{role: :owner} = invitation) do
    PlausibleWeb.Email.ownership_transfer_accepted(invitation)
    |> Plausible.Mailer.send_email_safe()
  end

  defp notify_invitation_accepted(invitation) do
    PlausibleWeb.Email.invitation_accepted(invitation)
    |> Plausible.Mailer.send_email_safe()
  end

  defp notify_invitation_rejected(%Invitation{role: :owner} = invitation) do
    PlausibleWeb.Email.ownership_transfer_rejected(invitation)
    |> Plausible.Mailer.send_email_safe()
  end

  defp notify_invitation_rejected(invitation) do
    PlausibleWeb.Email.invitation_rejected(invitation)
    |> Plausible.Mailer.send_email_safe()
  end

  def remove_invitation(conn, %{"invitation_id" => invitation_id}) do
    invitation =
      Repo.get_by!(Invitation, invitation_id: invitation_id)
      |> Repo.preload(:site)

    Repo.delete!(invitation)

    conn
    |> put_flash(:success, "You have removed the invitation for #{invitation.email}")
    |> redirect(to: Routes.site_path(conn, :settings_general, invitation.site.domain))
  end
end
