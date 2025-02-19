defmodule Plausible.Site.Memberships.CreateInvitation do
  @moduledoc """
  Service for inviting new or existing users to a sites, including ownershhip
  transfers.
  """

  alias Plausible.Auth.User
  alias Plausible.Site
  alias Plausible.Repo
  alias Plausible.Teams
  use Plausible

  @type invite_error() ::
          Ecto.Changeset.t()
          | :already_a_member
          | :transfer_to_self
          | :no_plan
          | {:over_limit, non_neg_integer()}
          | :forbidden

  @type invitation :: %Teams.GuestInvitation{} | %Teams.SiteTransfer{}

  @spec create_invitation(Site.t(), User.t(), String.t(), atom()) ::
          {:ok, invitation} | {:error, invite_error()}
  @doc """
  Invites a new team member to the given site. Returns either
  `%Teams.GuestInvitation{}` or `%Teams.SiteTransfer{}` struct
  and sends the invitee an email to accept this invitation.

  The inviter must have enough permissions to invite the new team member,
  otherwise this function returns `{:error, :forbidden}`.

  If the new team member role is `:owner`, this function handles the invitation
  as an ownership transfer and requires the inviter to be the owner of the site.
  """
  def create_invitation(site, inviter, invitee_email, role) do
    Repo.transaction(fn ->
      do_invite(site, inviter, invitee_email, role)
    end)
  end

  @spec bulk_create_invitation([Site.t()], User.t(), String.t(), atom(), Keyword.t()) ::
          {:ok, [invitation]} | {:error, invite_error()}
  def bulk_create_invitation(sites, inviter, invitee_email, role, opts \\ []) do
    Repo.transaction(fn ->
      for site <- sites do
        do_invite(site, inviter, invitee_email, role, opts)
      end
    end)
  end

  defp do_invite(site, inviter, invitee_email, role, opts \\ []) do
    with site <- Repo.preload(site, [:owner, :team]),
         :ok <-
           Teams.Invitations.check_invitation_permissions(
             site,
             inviter,
             role,
             opts
           ),
         :ok <-
           Teams.Invitations.check_team_member_limit(
             site.team,
             role,
             invitee_email
           ),
         invitee = Plausible.Auth.find_user_by(email: invitee_email),
         :ok <-
           Teams.Invitations.ensure_transfer_valid(
             site.team,
             invitee,
             role
           ),
         :ok <-
           Teams.Invitations.ensure_new_membership(
             site,
             invitee,
             role
           ),
         {:ok, invitation_or_transfer} <-
           Teams.Invitations.invite(site, invitee_email, role, inviter) do
      send_invitation_email(invitation_or_transfer, invitee)

      invitation_or_transfer
    else
      {:error, cause} -> Repo.rollback(cause)
    end
  end

  defp send_invitation_email(%Teams.GuestInvitation{} = guest_invitation, invitee) do
    guest_invitation
    |> Repo.preload([:site, team_invitation: :inviter])
    |> Teams.Invitations.send_invitation_email(invitee)
  end

  defp send_invitation_email(%Teams.SiteTransfer{} = site_transfer, invitee) do
    site_transfer
    |> Repo.preload([:site, :initiator])
    |> Teams.Invitations.send_invitation_email(invitee)
  end
end
