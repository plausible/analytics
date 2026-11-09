defmodule Plausible.Teams.Sites.Transfer do
  @moduledoc """
  Service for transferring sites.
  """

  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  import Ecto.Query, only: [from: 2]

  @type transfer_error() ::
          Billing.Quota.Limits.over_limits_error()
          | Ecto.Changeset.t()
          | :transfer_to_self
          | :no_plan
          | :multiple_teams
          | :permission_denied

  @doc """
  Creates a site transfer to the given email and sends the invitee
  an email to accept it. Only team owners and admins can do this.

  If a transfer of this site to this email already exists, the email is
  sent again with the existing transfer link. The transfer keeps its
  original expiry.

  Rejects if there's an existing guest invitation (not transfer) for
  this site and this email.
  """
  @spec initiate(Site.t(), Auth.User.t(), String.t()) ::
          {:ok, Teams.SiteTransfer.t()} | {:error, Ecto.Changeset.t() | :permission_denied}
  def initiate(site, initiator, invitee_email) do
    site = Repo.preload(site, :team)

    Repo.transaction(fn ->
      with :ok <- Teams.TeamRolePermissions.ensure_can_manage_team(site.team, initiator),
           {:ok, site_transfer} <-
             create_site_transfer(site, initiator, invitee_email) do
        invitee = Auth.find_user_by(email: invitee_email)

        site_transfer
        |> Repo.preload([:site, :initiator])
        |> Teams.Invitations.send_invitation_email(invitee)

        site_transfer
      else
        {:error, cause} -> Repo.rollback(cause)
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

  @spec accept(Teams.SiteTransfer.t(), Auth.User.t(), Teams.Team.t() | nil, Keyword.t()) ::
          {:ok, %{team: Teams.Team.t(), team_memberships: [Teams.Membership.t()], site: Site.t()}}
          | {:error, transfer_error()}
  def accept(site_transfer, new_owner, team, opts \\ []) do
    site = Repo.preload(site_transfer.site, :team)

    with {:ok, new_team} <- maybe_get_team(new_owner, team),
         :ok <- ensure_transfer_valid(site.team, new_team),
         :ok <- Teams.TeamRolePermissions.ensure_can_manage_team(new_team, new_owner),
         :ok <- Teams.Invitations.ensure_can_take_ownership(site, new_team, opts),
         :ok <- Teams.Invitations.accept_site_transfer(site_transfer, new_team, opts) do
      Teams.Invitations.send_transfer_accepted_email(site_transfer, new_team)

      site = site |> Repo.reload!() |> Repo.preload(ownerships: :user)

      {:ok, %{team: new_team, team_memberships: site.ownerships, site: site}}
    end
  end

  defp transfer_ownership(site, new_owner, team) do
    site = Repo.preload(site, :team)

    with {:ok, new_team} <- maybe_get_team(new_owner, team),
         :ok <- ensure_transfer_valid(site.team, new_team),
         :ok <- Teams.TeamRolePermissions.ensure_can_manage_team(new_team, new_owner),
         :ok <- Teams.Invitations.ensure_can_take_ownership(site, new_team),
         :ok <- Teams.Invitations.transfer_site(site, new_team) do
      site = site |> Repo.reload!() |> Repo.preload(ownerships: :user)

      {:ok, site.ownerships}
    end
  end

  defp ensure_transfer_valid(team, new_team) do
    if team.id == new_team.id do
      {:error, :transfer_to_self}
    else
      :ok
    end
  end

  @doc """
  Creates a site transfer without sending any email. If a transfer of this
  site to this email already exists, returns it and sets its `updated_at`
  to `now`.
  """
  @spec create_site_transfer(Site.t(), Auth.User.t(), String.t(), NaiveDateTime.t()) ::
          {:ok, Teams.SiteTransfer.t()} | {:error, Ecto.Changeset.t()}
  def create_site_transfer(site, initiator, invitee_email, now \\ NaiveDateTime.utc_now(:second)) do
    changeset = Teams.SiteTransfer.changeset(site, initiator: initiator, email: invitee_email)

    if guest_invitation_exists?(site, invitee_email) do
      {:error, Ecto.Changeset.add_error(changeset, :invitation, "already sent")}
    else
      Repo.insert(changeset,
        on_conflict: [set: [updated_at: now]],
        conflict_target: [:email, :site_id],
        returning: true
      )
    end
  end

  defp guest_invitation_exists?(site, email) do
    Repo.exists?(
      from ti in Teams.Invitation,
        inner_join: gi in assoc(ti, :guest_invitations),
        where: ti.email == ^email,
        where: ti.team_id == ^site.team_id,
        where: gi.site_id == ^site.id
    )
  end

  defp maybe_get_team(_user, %Teams.Team{} = team) do
    {:ok, team}
  end

  defp maybe_get_team(user, nil) do
    Teams.get_or_create(user)
  end
end
