defmodule Plausible.Teams.Test do
  @moduledoc """
  Convenience assertions for teams schema transition
  """
  alias Plausible.Repo
  alias Plausible.Teams

  import Ecto.Query

  use ExUnit.CaseTemplate

  import Plausible.Factory

  defmacro __using__(_) do
    quote do
      import Plausible.Teams.Test
    end
  end

  def new_site(args \\ []) do
    args =
      if user = args[:owner] do
        {:ok, team} = Teams.get_or_create(user)

        args
        |> Keyword.put(:team, team)
        |> Keyword.put(:members, [user])
      else
        user = new_user()
        {:ok, team} = Teams.get_or_create(user)

        args
        |> Keyword.put(:team, team)
        |> Keyword.put(:members, [user])
      end

    :site
    |> insert(args)
    |> Repo.preload(:memberships)
  end

  def new_team() do
    new_user()
    |> Map.fetch!(:team_memberships)
    |> List.first()
  end

  def new_user(args \\ []) do
    user = insert(:user, args)

    if user.trial_expiry_date do
      {:ok, _team} = Teams.get_or_create(user)
    end

    Repo.preload(user, :team_memberships)
  end

  def add_guest(site, args \\ []) do
    user = Keyword.get(args, :user, new_user())
    role = Keyword.fetch!(args, :role)
    team = Repo.preload(site, :team).team

    insert(:site_membership, user: user, role: translate_role_to_old_model(role), site: site)

    team_membership = insert(:team_membership, team: team, user: user, role: :guest)
    insert(:guest_membership, team_membership: team_membership, site: site, role: role)

    user |> Repo.preload([:site_memberships, :team_memberships])
  end

  def invite_guest(site, invitee_or_email, args \\ []) when not is_nil(invitee_or_email) do
    role = Keyword.fetch!(args, :role)
    inviter = Keyword.fetch!(args, :inviter)
    team = Repo.preload(site, :team).team

    email =
      case invitee_or_email do
        %{email: email} -> email
        email when is_binary(email) -> email
      end

    old_model_invitation =
      insert(:invitation,
        email: email,
        inviter: inviter,
        role: translate_role_to_old_model(role),
        site: site
      )

    team_invitation =
      insert(:team_invitation,
        team: team,
        email: email,
        inviter: inviter,
        role: :guest
      )

    insert(:guest_invitation,
      invitation_id: old_model_invitation.invitation_id,
      team_invitation: team_invitation,
      site: site,
      role: role
    )

    old_model_invitation
  end

  def invite_transfer(site, invitee, args \\ []) do
    inviter = Keyword.fetch!(args, :inviter)

    old_model_invitation =
      insert(:invitation, email: invitee.email, inviter: inviter, role: :owner, site: site)

    insert(:site_transfer,
      transfer_id: old_model_invitation.invitation_id,
      email: invitee.email,
      site: site,
      initiator: inviter
    )

    old_model_invitation
  end

  def revoke_membership(site, user) do
    Repo.delete_all(
      from sm in Plausible.Site.Membership,
        where: sm.user_id == ^user.id and sm.site_id == ^site.id
    )

    Repo.delete_all(
      from tm in Plausible.Teams.Membership,
        where: tm.user_id == ^user.id and tm.team_id == ^site.team.id
    )

    user |> Repo.preload([:site_memberships, :team_memberships])
  end

  def subscribe_to_growth_plan(user) do
    {:ok, team} = Teams.get_or_create(user)

    insert(:growth_subscription, user: user, team: team)
    user
  end

  def subscribe_to_business_plan(user) do
    {:ok, team} = Teams.get_or_create(user)

    insert(:business_subscription, user: user, team: team)
    user
  end

  def subscribe_to_plan(user, paddle_plan_id, attrs \\ []) do
    {:ok, team} = Teams.get_or_create(user)
    attrs = Keyword.merge([user: user, team: team, paddle_plan_id: paddle_plan_id], attrs)
    subscription = insert(:subscription, attrs)
    %{user | subscription: subscription}
  end

  def subscribe_to_enterprise_plan(user, attrs \\ []) do
    {:ok, team} = Teams.get_or_create(user)

    {subscription?, attrs} = Keyword.pop(attrs, :subscription?, true)

    enterprise_plan = insert(:enterprise_plan, Keyword.merge([user: user, team: team], attrs))

    if subscription? do
      insert(:subscription,
        team: team,
        user: user,
        paddle_plan_id: enterprise_plan.paddle_plan_id
      )
    end

    user
  end

  def assert_team_exists(user, team_id \\ nil) do
    assert %{team_memberships: memberships} = Repo.preload(user, team_memberships: :team)

    tm =
      case memberships do
        [tm] -> tm
        _ -> raise "Team doesn't exist for user #{user.id}"
      end

    assert tm.role == :owner
    assert tm.team.id

    if team_id do
      assert tm.team.id == team_id
    end

    tm.team
  end

  def assert_team_membership(user, team, role \\ :owner) do
    if role == :owner do
      assert membership =
               Repo.get_by(Teams.Membership,
                 team_id: team.id,
                 user_id: user.id,
                 role: role
               )

      membership
    else
      assert team_membership =
               Repo.get_by(Teams.Membership,
                 team_id: team.id,
                 user_id: user.id,
                 role: :guest
               )

      assert membership =
               Repo.get_by(Teams.GuestMembership,
                 team_membership_id: team_membership.id,
                 role: role
               )

      membership
    end
  end

  def assert_team_attached(site, team_id \\ nil) do
    assert site = %{team: team} = site |> Repo.reload!() |> Repo.preload([:team, :owner])

    assert membership = assert_team_membership(site.owner, team)

    assert membership.team_id == team.id

    if team_id do
      assert team.id == team_id
    end

    team
  end

  def assert_guest_invitation(team, site, email, role) do
    assert team_invitation =
             Repo.get_by(Plausible.Teams.Invitation,
               email: email,
               team_id: team.id,
               role: :guest
             )

    assert Repo.get_by(Plausible.Teams.GuestInvitation,
             team_invitation_id: team_invitation.id,
             site_id: site.id,
             role: role
           )
  end

  def assert_guest_membership(team, site, user, role) do
    assert team_membership =
             Repo.get_by(Plausible.Teams.Membership,
               user_id: user.id,
               team_id: team.id,
               role: :guest
             )

    assert Repo.get_by(Plausible.Teams.GuestMembership,
             team_membership_id: team_membership.id,
             site_id: site.id,
             role: role
           )
  end

  defp translate_role_to_old_model(:editor), do: :admin
  defp translate_role_to_old_model(role), do: role
end
