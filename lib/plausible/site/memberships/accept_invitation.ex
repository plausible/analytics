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

  @type accept_error() ::
          :invitation_not_found
          | Billing.Quota.Limits.over_limits_error()
          | Ecto.Changeset.t()
          | :no_plan

  @spec bulk_transfer_ownership_direct([Site.t()], Auth.User.t()) ::
          {:ok, [Site.Membership.t()]} | {:error, transfer_error()}
  def bulk_transfer_ownership_direct(sites, new_owner) do
    Repo.transaction(fn ->
      for site <- sites do
        case transfer_ownership(site, new_owner) do
          {:ok, membership} ->
            membership

          {:error, error} ->
            Repo.rollback(error)
        end
      end
    end)
  end

  @spec accept_invitation(String.t(), Auth.User.t()) ::
          {:ok, Teams.Membership.t()} | {:error, accept_error()}
  def accept_invitation(invitation_or_transfer_id, user) do
    with {:ok, invitation_or_transfer} <-
           Teams.Invitations.find_for_user(invitation_or_transfer_id, user) do
      case invitation_or_transfer do
        %Teams.SiteTransfer{} = site_transfer ->
          do_accept_ownership_transfer(site_transfer, user)

        %Teams.GuestInvitation{} = guest_invitation ->
          do_accept_invitation(guest_invitation, user)
      end
    end
  end

  defp transfer_ownership(site, new_owner) do
    site = Repo.preload(site, :team)

    with :ok <-
           Plausible.Teams.Invitations.ensure_transfer_valid(
             site.team,
             new_owner,
             :owner
           ),
         {:ok, new_team} = Plausible.Teams.get_or_create(new_owner),
         :ok <- Plausible.Teams.Invitations.ensure_can_take_ownership(site, new_team),
         :ok <- Plausible.Teams.Invitations.transfer_site(site, new_owner) do
      site = site |> Repo.reload!() |> Repo.preload(ownership: :user)

      {:ok, site.ownership}
    end
  end

  defp do_accept_ownership_transfer(site_transfer, user) do
    site = Repo.preload(site_transfer.site, :team)

    with :ok <-
           Plausible.Teams.Invitations.ensure_transfer_valid(
             site.team,
             user,
             :owner
           ),
         {:ok, team} = Plausible.Teams.get_or_create(user),
         :ok <- Plausible.Teams.Invitations.ensure_can_take_ownership(site, team),
         :ok <- Teams.Invitations.accept_site_transfer(site_transfer, user) do
      Teams.Invitations.send_transfer_accepted_email(site_transfer)

      site = site |> Repo.reload!() |> Repo.preload(ownership: :user)

      {:ok, %{team_membership: site.ownership, site: site}}
    end
  end

  defp do_accept_invitation(guest_invitation, user) do
    Teams.Invitations.accept_guest_invitation(guest_invitation, user)
  end
end
