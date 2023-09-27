defmodule Plausible.Site.Memberships.RejectInvitation do
  @moduledoc """
  Service for rejecting invitations.
  """

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site.Memberships.Invitations

  @spec reject_invitation(String.t(), Auth.User.t()) ::
          {:ok, Auth.Invitation.t()} | {:error, :invitation_not_found}
  def reject_invitation(invitation_id, user) do
    with {:ok, invitation} <- Invitations.find_for_user(invitation_id, user) do
      Repo.delete!(invitation)
      notify_invitation_rejected(invitation)

      {:ok, invitation}
    end
  end

  defp notify_invitation_rejected(%Auth.Invitation{role: :owner} = invitation) do
    PlausibleWeb.Email.ownership_transfer_rejected(invitation)
    |> Plausible.Mailer.send()
  end

  defp notify_invitation_rejected(invitation) do
    PlausibleWeb.Email.invitation_rejected(invitation)
    |> Plausible.Mailer.send()
  end
end
