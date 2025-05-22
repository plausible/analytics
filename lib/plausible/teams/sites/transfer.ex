defmodule Plausible.Teams.Sites.Transfer do
  @moduledoc """
  Service for transferring sites.
  """

  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  @type transfer_error() ::
          Billing.Quota.Limits.over_limits_error()
          | Ecto.Changeset.t()
          | :transfer_to_self
          | :no_plan
          | :multiple_teams
          | :permission_denied

  # XXX: remove with kaffy
  @spec bulk_transfer([Site.t()], Auth.User.t(), Teams.Team.t() | nil) ::
          {:ok, [Teams.Membership.t()]} | {:error, transfer_error()}
  def bulk_transfer(sites, new_owner, team \\ nil) do
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
      Teams.Invitations.send_team_changed_email(site, user, new_team)
      :ok
    end
  end

  @spec accept(Teams.SiteTransfer.t(), Auth.User.t(), Teams.Team.t() | nil) ::
          {:ok, %{team: Teams.Team.t(), team_memberships: [Teams.Membership.t()], site: Site.t()}}
          | {:error, transfer_error()}
  def accept(site_transfer, new_owner, team) do
    site = Repo.preload(site_transfer.site, :team)

    with {:ok, new_team} <- maybe_get_team(new_owner, team),
         :ok <- Teams.Invitations.ensure_transfer_valid(site.team, new_team, :owner),
         :ok <- Teams.Invitations.check_can_transfer_site(new_team, new_owner),
         :ok <- Teams.Invitations.ensure_can_take_ownership(site, new_team),
         :ok <- Teams.Invitations.accept_site_transfer(site_transfer, new_team) do
      Teams.Invitations.send_transfer_accepted_email(site_transfer, new_team)

      site = site |> Repo.reload!() |> Repo.preload(ownerships: :user)

      {:ok, %{team: new_team, team_memberships: site.ownerships, site: site}}
    end
  end

  defp transfer_ownership(site, new_owner, team) do
    site = Repo.preload(site, :team)

    with {:ok, new_team} <- maybe_get_team(new_owner, team),
         :ok <- Teams.Invitations.ensure_transfer_valid(site.team, new_team, :owner),
         :ok <- Teams.Invitations.check_can_transfer_site(new_team, new_owner),
         :ok <- Teams.Invitations.ensure_can_take_ownership(site, new_team),
         :ok <- Teams.Invitations.transfer_site(site, new_team) do
      site = site |> Repo.reload!() |> Repo.preload(ownerships: :user)

      {:ok, site.ownerships}
    end
  end

  defp maybe_get_team(_user, %Teams.Team{} = team) do
    {:ok, team}
  end

  defp maybe_get_team(user, nil) do
    Teams.get_or_create(user)
  end
end
