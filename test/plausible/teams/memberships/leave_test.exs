defmodule Plausible.Teams.Memberships.LeaveTest do
  use Plausible.DataCase, async: true
  use Plausible
  use Plausible.Repo
  use Plausible.Teams.Test
  use Bamboo.Test

  alias Plausible.Teams.Memberships.Leave

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  test "removes a member from a team" do
    user = new_user()
    _site = new_site(owner: user)
    team = team_of(user)
    add_member(team, role: :owner)

    assert {:ok, _} = Leave.leave(team, user)

    refute_team_member(user, team)

    assert_email_delivered_with(
      to: [nil: user.email],
      subject: @subject_prefix <> "You have left \"#{team.name}\" team"
    )

    assert Repo.reload(user)
  end

  test "when member leaves, associated personal segment is deleted" do
    user = new_user()
    site = new_site(owner: user)
    team = team_of(user)
    add_member(team, role: :owner)

    segment =
      insert(:segment,
        type: :personal,
        owner: user,
        site: site,
        name: "personal segment"
      )

    assert {:ok, _} = Leave.leave(team, user)

    refute Repo.reload(segment)
  end

  test "when member is removed, associated site segment will be owner-less" do
    user = new_user()
    site = new_site(owner: user)
    team = team_of(user)
    add_member(team, role: :owner)

    segment =
      insert(:segment,
        type: :site,
        owner: user,
        site: site,
        name: "site segment"
      )

    assert {:ok, _} = Leave.leave(team, user)

    assert Repo.reload(segment).owner_id == nil
  end

  test "can't remove the only owner" do
    user = new_user()
    _site = new_site(owner: user)
    team = team_of(user)

    assert {:error, :only_one_owner} = Leave.leave(team, user)

    assert_team_membership(user, team, :owner)
  end

  on_ee do
    describe "SSO user" do
      setup [:create_user, :create_team, :setup_sso, :provision_sso_user]

      test "removes SSO user along with membership", %{team: team, user: user} do
        add_member(team, role: :owner)

        assert {:ok, _} = Leave.leave(team, user)

        refute_team_member(user, team)

        assert_email_delivered_with(
          to: [nil: user.email],
          subject: @subject_prefix <> "You have left \"#{team.name}\" team"
        )

        refute Repo.reload(user)
      end
    end
  end
end
