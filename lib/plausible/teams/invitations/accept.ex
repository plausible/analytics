defmodule Plausible.Teams.Invitations.Accept do
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

  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.Teams

  @type accept_error() ::
          :invitation_not_found
          | Billing.Quota.Limits.over_limits_error()
          | Ecto.Changeset.t()
          | :no_plan
          | :transfer_to_self
          | :multiple_teams
          | :permission_denied

  @spec accept(String.t(), Auth.User.t(), Teams.Team.t() | nil) ::
          {:ok, map()} | {:error, accept_error()}
  def accept(invitation_or_transfer_id, user, team \\ nil) do
    with {:ok, invitation_or_transfer} <-
           Teams.Invitations.find_for_user(invitation_or_transfer_id, user) do
      case invitation_or_transfer do
        %Teams.SiteTransfer{} = site_transfer ->
          Teams.Sites.Transfer.accept(site_transfer, user, team)

        %Teams.Invitation{} = team_invitation ->
          Teams.Invitations.accept_team_invitation(team_invitation, user)

        %Teams.GuestInvitation{} = guest_invitation ->
          Teams.Invitations.accept_guest_invitation(guest_invitation, user)
      end
    end
  end
end
