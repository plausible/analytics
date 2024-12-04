defmodule Plausible.Site.Memberships.CreateInvitation do
  @moduledoc """
  Service for inviting new or existing users to a sites, including ownershhip
  transfers.
  """

  alias Plausible.Auth.{User, Invitation}
  alias Plausible.{Site, Sites, Site.Membership}
  alias Plausible.Billing.Quota
  import Ecto.Query
  use Plausible

  @type invite_error() ::
          Ecto.Changeset.t()
          | :already_a_member
          | :transfer_to_self
          | :no_plan
          | {:over_limit, non_neg_integer()}
          | :forbidden

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
         :ok <-
           Plausible.Teams.Invitations.check_invitation_permissions(
             site,
             inviter,
             role,
             opts
           ),
         :ok <-
           Plausible.Teams.Adapter.Read.Invitations.check_team_member_limit(
             inviter,
             site,
             role,
             invitee_email
           ),
         invitee = Plausible.Auth.find_user_by(email: invitee_email),
         :ok <-
           Plausible.Teams.Adapter.Read.Invitations.ensure_transfer_valid(
             inviter,
             site,
             invitee,
             role
           ),
         :ok <-
           Plausible.Teams.Adapter.Read.Invitations.ensure_new_membership(
             inviter,
             site,
             invitee,
             role
           ),
         %Ecto.Changeset{} = changeset <- Invitation.new(attrs),
         {:ok, invitation} <- Plausible.Repo.insert(changeset) do
      Plausible.Teams.Invitations.invite_sync(site, invitation)

      Plausible.Teams.Adapter.Read.Invitations.send_invitation_email(inviter, invitation, invitee)

      invitation
    else
      {:error, cause} -> Plausible.Repo.rollback(cause)
    end
  end

  @doc false
  def send_invitation_email(invitation, invitee) do
    invitation = Plausible.Repo.preload(invitation, [:site, :inviter])

    email =
      case {invitee, invitation.role} do
        {invitee, :owner} ->
          PlausibleWeb.Email.ownership_transfer_request(
            invitation.email,
            invitation.invitation_id,
            invitation.site,
            invitation.inviter,
            invitee
          )

        {nil, _role} ->
          PlausibleWeb.Email.new_user_invitation(
            invitation.email,
            invitation.invitation_id,
            invitation.site,
            invitation.inviter
          )

        {%User{}, _role} ->
          PlausibleWeb.Email.existing_user_invitation(
            invitation.email,
            invitation.site,
            invitation.inviter
          )
      end

    Plausible.Mailer.send(email)
  end

  @doc false
  def ensure_new_membership(_site, _invitee, :owner) do
    :ok
  end

  def ensure_new_membership(site, invitee, _role) do
    if invitee && Sites.is_member?(invitee.id, site) do
      {:error, :already_a_member}
    else
      :ok
    end
  end

  @doc false
  def check_team_member_limit(_site, :owner, _invitee_email) do
    :ok
  end

  def check_team_member_limit(site, _role, invitee_email) do
    team = Plausible.Repo.preload(site, :team).team
    limit = Plausible.Teams.Billing.team_member_limit(team)
    usage = Plausible.Teams.Billing.team_member_usage(team, exclude_emails: [invitee_email])

    if Quota.below_limit?(usage, limit),
      do: :ok,
      else: {:error, {:over_limit, limit}}
  end
end
