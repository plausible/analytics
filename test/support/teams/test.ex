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

  def set_current_team(conn, team) do
    Plug.Conn.put_session(conn, :current_team_id, team.identifier)
  end

  def new_site(args \\ []) do
    args =
      cond do
        user = args[:owner] ->
          {owner, args} = Keyword.pop(args, :owner)
          {:ok, team} = Teams.get_or_create(user)

          args
          |> Keyword.put(:owners, [owner])
          |> Keyword.put(:team, team)

        args[:team] ->
          args

        true ->
          user = new_user()
          {:ok, team} = Teams.get_or_create(user)

          args
          |> Keyword.put(:team, team)
      end

    :site
    |> insert(args)
  end

  def new_team() do
    new_user()
    |> Map.fetch!(:team_memberships)
    |> List.first()
  end

  def new_user(args \\ []) do
    {team_args, args} = Keyword.pop(args, :team, [])
    {trial_expiry_date, args} = Keyword.pop(args, :trial_expiry_date)
    user = insert(:user, args)

    trial_expiry_date =
      if team_args != [] && !trial_expiry_date do
        Date.add(Date.utc_today(), 30)
      else
        trial_expiry_date
      end

    if trial_expiry_date do
      {:ok, team} = Teams.get_or_create(user)

      team_args =
        Keyword.merge(team_args, trial_expiry_date: trial_expiry_date)

      team
      |> Ecto.Changeset.change(team_args)
      |> Repo.update!()
    end

    Repo.preload(user, team_memberships: :team)
  end

  def team_of(subject, opts \\ [])

  def team_of(%{team_memberships: [%{role: :owner, team: %Teams.Team{} = team}]}, opts) do
    if opts[:with_subscription?] do
      Plausible.Teams.with_subscription(team)
    else
      team
    end
  end

  def team_of(user, opts) do
    case Plausible.Teams.get_by_owner(user) do
      {:ok, team} ->
        if opts[:with_subscription?] do
          Plausible.Teams.with_subscription(team)
        else
          team
        end

      _ ->
        nil
    end
  end

  def add_guest(site, args \\ []) do
    user = Keyword.get(args, :user, new_user())
    role = Keyword.fetch!(args, :role)
    team = Repo.preload(site, :team).team

    team_membership =
      build(:team_membership, team: team, user: user, role: :guest)
      |> Repo.insert!(
        on_conflict: [set: [updated_at: NaiveDateTime.utc_now()]],
        conflict_target: [:team_id, :user_id],
        returning: true
      )

    insert(:guest_membership, site: site, team_membership: team_membership, role: role)

    user |> Repo.preload(:team_memberships)
  end

  def add_member(team, args \\ []) do
    user = Keyword.get(args, :user, new_user())
    role = Keyword.fetch!(args, :role)

    insert(:team_membership, team: team, user: user, role: role)

    user |> Repo.preload(:team_memberships)
  end

  def invite_guest(site, invitee_or_email, args \\ []) when not is_nil(invitee_or_email) do
    {role, args} = Keyword.pop!(args, :role)
    {inviter, args} = Keyword.pop!(args, :inviter)
    {team_invitation_args, args} = Keyword.pop(args, :team_invitation, [])
    team = Repo.preload(site, :team).team

    email =
      case invitee_or_email do
        %{email: email} -> email
        email when is_binary(email) -> email
      end

    team_invitation =
      insert(
        :team_invitation,
        Keyword.merge(
          [
            team: team,
            email: email,
            inviter: inviter,
            role: :guest
          ],
          team_invitation_args
        )
      )

    insert(
      :guest_invitation,
      Keyword.merge(
        [
          team_invitation: team_invitation,
          site: site,
          role: role
        ],
        args
      )
    )
  end

  def invite_member(team, invitee_or_email, args \\ []) when not is_nil(invitee_or_email) do
    {role, args} = Keyword.pop!(args, :role)
    {inviter, args} = Keyword.pop!(args, :inviter)

    email =
      case invitee_or_email do
        %{email: email} -> email
        email when is_binary(email) -> email
      end

    insert(
      :team_invitation,
      Keyword.merge(
        [
          team: team,
          email: email,
          inviter: inviter,
          role: role
        ],
        args
      )
    )
  end

  def invite_transfer(site, invitee_or_email, args \\ []) do
    {inviter, args} = Keyword.pop!(args, :inviter)

    email =
      case invitee_or_email do
        %{email: email} -> email
        email when is_binary(email) -> email
      end

    insert(
      :site_transfer,
      Keyword.merge(
        [
          email: email,
          site: site,
          initiator: inviter
        ],
        args
      )
    )
  end

  def revoke_membership(site, user) do
    Repo.delete_all(
      from tm in Plausible.Teams.Membership,
        where: tm.user_id == ^user.id and tm.team_id == ^site.team.id
    )

    user |> Repo.preload(:team_memberships)
  end

  def subscribe_to_growth_plan(user, attrs \\ []) do
    {:ok, team} = Teams.get_or_create(user)
    attrs = Keyword.merge([team: team], attrs)

    insert(:growth_subscription, attrs)
    user
  end

  def subscribe_to_business_plan(user) do
    {:ok, team} = Teams.get_or_create(user)

    insert(:business_subscription, team: team)
    user
  end

  def subscribe_to_plan(user, paddle_plan_id, attrs \\ []) do
    {:ok, team} = Teams.get_or_create(user)
    attrs = Keyword.merge([team: team, paddle_plan_id: paddle_plan_id], attrs)

    insert(:subscription, attrs)

    user
  end

  def subscribe_to_enterprise_plan(user, attrs \\ []) do
    {:ok, team} = Teams.get_or_create(user)

    {subscription?, attrs} = Keyword.pop(attrs, :subscription?, true)
    {subscription_attrs, attrs} = Keyword.pop(attrs, :subscription, [])

    enterprise_plan = insert(:enterprise_plan, Keyword.merge([team: team], attrs))

    if subscription? do
      insert(
        :subscription,
        Keyword.merge(
          [
            team: team,
            paddle_plan_id: enterprise_plan.paddle_plan_id
          ],
          subscription_attrs
        )
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
    assert membership =
             Repo.get_by(Teams.Membership,
               team_id: team.id,
               user_id: user.id,
               role: role
             )

    membership
  end

  def refute_team_member(user, team) do
    refute Repo.get_by(Teams.Membership,
             team_id: team.id,
             user_id: user.id
           )
  end

  def assert_team_attached(site, team_id \\ nil) do
    assert site = %{team: team} = site |> Repo.reload!() |> Repo.preload([:team, :owners])

    for owner <- site.owners do
      assert membership = assert_team_membership(owner, team)

      assert membership.team_id == team.id
    end

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

  def assert_site_transfer(site, %Plausible.Auth.User{} = user) do
    assert_site_transfer(site, user.email)
  end

  def assert_site_transfer(site, email) when is_binary(email) do
    assert Repo.get_by(Plausible.Teams.SiteTransfer,
             site_id: site.id,
             email: email
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

  def assert_non_guest_membership(team, site, user) do
    assert team_membership =
             Repo.get_by(Plausible.Teams.Membership,
               user_id: user.id,
               team_id: team.id
             )

    assert team_membership.role != :guest

    refute Repo.get_by(Plausible.Teams.GuestMembership,
             team_membership_id: team_membership.id,
             site_id: site.id
           )
  end

  def subscription_of(%Plausible.Auth.User{} = user) do
    user
    |> team_of()
    |> subscription_of()
  end

  def subscription_of(team) do
    team
    |> Plausible.Teams.with_subscription()
    |> Map.fetch!(:subscription)
  end
end
