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

  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  require Logger

  @type transfer_error() ::
          Billing.Quota.Limits.over_limits_error()
          | Ecto.Changeset.t()
          | :transfer_to_self
          | :no_plan
          | :multiple_teams
          | :permission_denied

  @type accept_error() ::
          :invitation_not_found
          | Billing.Quota.Limits.over_limits_error()
          | Ecto.Changeset.t()
          | :no_plan
          | :transfer_to_self
          | :multiple_teams
          | :permission_denied

  @type membership() :: %Teams.Membership{}

  @spec bulk_transfer_ownership_direct([Site.t()], Auth.User.t(), Teams.Team.t() | nil) ::
          {:ok, [membership]} | {:error, transfer_error()}
  def bulk_transfer_ownership_direct(sites, new_owner, team \\ nil) do
    Repo.transaction(fn ->
      for site <- sites do
        case transfer_ownership(site, new_owner, team) do
          {:ok, membership} ->
            membership

          {:error, error} ->
            Repo.rollback(error)
        end
      end
    end)
  end

  @spec change_team(Site.t(), Auth.User.t(), Teams.Team.t()) ::
          :ok | {:error, transfer_error()}
  def change_team(site, user, new_team) do
    with {:ok, _} <- transfer_ownership(site, user, new_team) do
      :ok
    end
  end

  @spec accept_invitation(String.t(), Auth.User.t(), Teams.Team.t() | nil) ::
          {:ok, map()} | {:error, accept_error()}
  def accept_invitation(invitation_or_transfer_id, user, team \\ nil) do
    with {:ok, invitation_or_transfer} <-
           Teams.Invitations.find_for_user(invitation_or_transfer_id, user) do
      case invitation_or_transfer do
        %Teams.SiteTransfer{} = site_transfer ->
          do_accept_ownership_transfer(site_transfer, user, team)

        %Teams.Invitation{} = team_invitation ->
          do_accept_team_invitation(team_invitation, user)

        %Teams.GuestInvitation{} = guest_invitation ->
          do_accept_guest_invitation(guest_invitation, user)
      end
    end
  end

  defp transfer_ownership(site, new_owner, team) do
    site = Repo.preload(site, :team)

    with {:ok, new_team} <- maybe_get_team(new_owner, team),
         :ok <- Teams.Invitations.ensure_transfer_valid(site.team, new_team, :owner),
         :ok <- check_can_transfer_site(new_team, new_owner),
         :ok <- Teams.Invitations.ensure_can_take_ownership(site, new_team),
         :ok <- Teams.Invitations.transfer_site(site, new_team) do
      site = site |> Repo.reload!() |> Repo.preload(ownerships: :user)

      {:ok, site.ownerships}
    end
  end

  defp do_accept_ownership_transfer(site_transfer, new_owner, team) do
    site = Repo.preload(site_transfer.site, :team)

    with {:ok, new_team} <- maybe_get_team(new_owner, team),
         :ok <- Teams.Invitations.ensure_transfer_valid(site.team, new_team, :owner),
         :ok <- check_can_transfer_site(new_team, new_owner),
         :ok <- Teams.Invitations.ensure_can_take_ownership(site, new_team),
         :ok <- Teams.Invitations.accept_site_transfer(site_transfer, new_team) do
      Teams.Invitations.send_transfer_accepted_email(site_transfer)

      site = site |> Repo.reload!() |> Repo.preload(ownerships: :user)

      {:ok, %{team: new_team, team_memberships: site.ownerships, site: site}}
    end
  end

  defp maybe_get_team(_user, %Teams.Team{} = team) do
    {:ok, team}
  end

  defp maybe_get_team(user, nil) do
    Teams.get_or_create(user)
  end

  defp check_can_transfer_site(team, user) do
    if Teams.Memberships.can_transfer_site?(team, user) do
      :ok
    else
      {:error, :permission_denied}
    end
  end

  defp do_accept_guest_invitation(guest_invitation, user) do
    Teams.Invitations.accept_guest_invitation(guest_invitation, user)
  end

  defp do_accept_team_invitation(team_invitation, user) do
    Teams.Invitations.accept_team_invitation(team_invitation, user)
  end
end
