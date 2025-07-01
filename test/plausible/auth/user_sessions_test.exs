defmodule Plausible.Auth.UserSessionsTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test
  use Plausible

  import Phoenix.ChannelTest

  alias Plausible.Auth
  alias Plausible.Auth.UserSessions
  alias Plausible.Repo

  describe "list_for_user/2" do
    test "lists user sessions" do
      user = insert(:user)

      now = NaiveDateTime.utc_now(:second)
      thirty_minutes_ago = NaiveDateTime.shift(now, minute: -30)
      ten_hours_ago = NaiveDateTime.shift(now, hour: -10)
      ten_days_ago = NaiveDateTime.shift(now, day: -10)
      twenty_days_ago = NaiveDateTime.shift(now, day: -20)

      recent_session = insert_session(user, "Recent Device", thirty_minutes_ago)
      old_session = insert_session(user, "Old Device", ten_hours_ago)
      older_session = insert_session(user, "Older Device", ten_days_ago)
      _expired_session = insert_session(user, "Expired Device", twenty_days_ago)
      _rogue_session = insert_session(insert(:user), "Unrelated device", now)

      assert [session1, session2, session3] = UserSessions.list_for_user(user, now)

      assert session1.id == recent_session.id
      assert session2.id == old_session.id
      assert session3.id == older_session.id
    end
  end

  describe "count_for_users/2" do
    test "counts user sessions" do
      now = NaiveDateTime.utc_now(:second)
      thirty_minutes_ago = NaiveDateTime.shift(now, minute: -30)

      u1 = insert(:user)
      u2 = insert(:user)
      u3 = insert(:user)

      insert_session(u1, "Recent Device", thirty_minutes_ago)
      insert_session(u1, "Recent Device 2", thirty_minutes_ago)
      insert_session(u2, "Recent Device", thirty_minutes_ago)

      assert UserSessions.count_for_users([u1, u2, u3], now) == [{u1.id, 2}, {u2.id, 1}]
    end
  end

  on_ee do
    describe "list_for_sso_team/1,2" do
      test "lists only SSO member sessions for a given team" do
        %{team: sso_team, site: site} =
          setup_do(&create_user/1)
          |> setup_do(&create_team/1)
          |> setup_do(&create_site/1)
          |> setup_do(&setup_sso/1)

        %{team: _other_sso_team} =
          %{domain: "example2.com"}
          |> setup_do(&create_user/1)
          |> setup_do(&create_team/1)
          |> setup_do(&setup_sso/1)

        %{team: _other_team, user: other_member} =
          setup_do(&create_user/1)
          |> setup_do(&create_team/1)

        add_guest(site, user: other_member, role: :editor)
        _other_member_session = Auth.UserSessions.create!(other_member, "Unknown")

        %{user: sso_member} =
          %{user: %{name: "Jerry Wane", email: "wane@example.com"}}
          |> setup_do(&provision_sso_user/1)

        now = NaiveDateTime.utc_now(:second)

        sso_member_session =
          insert_session(sso_member, "Unknown", NaiveDateTime.add(now, -1, :hour))

        %{user: sso_member2} =
          %{user: %{name: "Joan McGuire", email: "joan@example.com"}}
          |> setup_do(&provision_sso_user/1)

        sso_member2_session1 =
          insert_session(sso_member2, "Unknown", NaiveDateTime.add(now, -2, :hour))

        sso_member2_session2 = insert_session(sso_member2, "Unknown", now)

        in_the_past = NaiveDateTime.add(NaiveDateTime.utc_now(:second), -1, :hour)

        _sso_member2_session_past =
          Auth.UserSessions.create!(sso_member2, "Unknown", timeout_at: in_the_past)

        team = new_site().team
        standard_member = add_member(team, role: :editor)
        _standard_member_session = insert_session(standard_member, "Unknown", now)

        %{user: other_sso_member} =
          %{user: %{name: "Veronica Dogwright", email: "veronica@example2.com"}}
          |> setup_do(&provision_sso_user/1)

        _other_sso_member_session = insert_session(other_sso_member, "Unknown", now)

        %{user: guest_sso_member} =
          %{user: %{name: "Jimmy Felon", email: "jimmy@example2.com"}}
          |> setup_do(&provision_sso_user/1)

        add_guest(site, user: Repo.reload!(guest_sso_member), role: :viewer)

        _guest_sso_member_session = insert_session(guest_sso_member, "Unknown", now)

        assert [s1, s2, s3] = Auth.UserSessions.list_sso_for_team(sso_team)

        assert s1.token == sso_member2_session2.token
        assert s2.token == sso_member_session.token
        assert s3.token == sso_member2_session1.token
      end
    end

    describe "revoke_sso_by_id/2" do
      test "deletes and disconnects user session" do
        %{team: sso_team} =
          setup_do(&create_user/1)
          |> setup_do(&create_team/1)
          |> setup_do(&setup_sso/1)

        %{user: user} =
          %{user: %{name: "Jerry Wane", email: "wane@example.com"}}
          |> setup_do(&provision_sso_user/1)

        now = NaiveDateTime.utc_now(:second)
        active_session = insert_session(user, "Unknown", now)
        another_session = insert_session(user, "Unknown", now)

        live_socket_id = "user_sessions:" <> Base.url_encode64(active_session.token)
        Phoenix.PubSub.subscribe(Plausible.PubSub, live_socket_id)

        assert :ok = UserSessions.revoke_sso_by_id(sso_team, active_session.id)

        assert [remaining_session] = Repo.preload(user, :sessions).sessions
        assert_broadcast "disconnect", %{}
        assert remaining_session.id == another_session.id
        refute Repo.reload(active_session)
        assert Repo.reload(another_session)
      end

      test "does not delete session of user on another team" do
        %{team: sso_team} =
          setup_do(&create_user/1)
          |> setup_do(&create_team/1)
          |> setup_do(&setup_sso/1)

        %{team: _other_sso_team} =
          %{domain: "example2.com"}
          |> setup_do(&create_user/1)
          |> setup_do(&create_team/1)
          |> setup_do(&setup_sso/1)

        %{user: user} =
          %{user: %{name: "Jerry Wane", email: "wane@example.com"}}
          |> setup_do(&provision_sso_user/1)

        now = NaiveDateTime.utc_now(:second)

        active_session = insert_session(user, "Unknown", now)

        %{user: other_user} =
          %{user: %{name: "Judy Wasteland", email: "judy@example2.com"}}
          |> setup_do(&provision_sso_user/1)

        other_session = insert_session(other_user, "Unknown", now)

        assert :ok = UserSessions.revoke_sso_by_id(sso_team, other_session.id)

        assert Repo.reload(active_session)
        assert Repo.reload(other_session)
      end

      test "does not revoke session of standard user" do
        %{team: sso_team} =
          setup_do(&create_user/1)
          |> setup_do(&create_team/1)
          |> setup_do(&setup_sso/1)

        user = add_member(sso_team, role: :editor)

        now = NaiveDateTime.utc_now(:second)
        active_session = insert_session(user, "Unknown", now)

        assert :ok = UserSessions.revoke_sso_by_id(sso_team, active_session.id)

        assert Repo.reload(active_session)
      end

      test "does not revoke session of a guest who happens to be SSO user" do
        %{team: sso_team, site: site} =
          setup_do(&create_user/1)
          |> setup_do(&create_site/1)
          |> setup_do(&create_team/1)
          |> setup_do(&setup_sso/1)

        %{team: _other_sso_team} =
          %{domain: "example2.com"}
          |> setup_do(&create_user/1)
          |> setup_do(&create_team/1)
          |> setup_do(&setup_sso/1)

        %{user: user} =
          %{user: %{name: "Judy Wasteland", email: "judy@example2.com"}}
          |> setup_do(&provision_sso_user/1)

        user = add_guest(site, user: Repo.reload!(user), role: :editor)

        now = NaiveDateTime.utc_now(:second)
        active_session = insert_session(user, "Unknown", now)

        assert :ok = UserSessions.revoke_sso_by_id(sso_team, active_session.id)

        assert Repo.reload(active_session)
      end

      test "executes gracefully when session does not exist" do
        %{team: sso_team} =
          setup_do(&create_user/1)
          |> setup_do(&create_team/1)
          |> setup_do(&setup_sso/1)

        %{user: user} =
          %{user: %{name: "Jerry Wane", email: "wane@example.com"}}
          |> setup_do(&provision_sso_user/1)

        now = NaiveDateTime.utc_now(:second)
        active_session = insert_session(user, "Unknown", now)

        Repo.delete!(active_session)

        assert :ok = UserSessions.revoke_sso_by_id(sso_team, active_session.id)
      end
    end
  end

  describe "last_used_humanize/2" do
    test "returns humanized relative time" do
      user = insert(:user)
      now = NaiveDateTime.utc_now(:second)
      thirty_minutes_ago = NaiveDateTime.shift(now, minute: -30)
      ninety_minutes_ago = NaiveDateTime.shift(now, minute: -90)
      ten_hours_ago = NaiveDateTime.shift(now, hour: -10)
      twenty_seven_hours_ago = NaiveDateTime.shift(now, hour: -27)
      fifty_hours_ago = NaiveDateTime.shift(now, hour: -50)
      ten_days_ago = NaiveDateTime.shift(now, day: -10)

      assert last_used_humanize(user, now) == "Just recently"
      assert last_used_humanize(user, thirty_minutes_ago) == "Just recently"
      assert last_used_humanize(user, ninety_minutes_ago) == "1 hour ago"
      assert last_used_humanize(user, ten_hours_ago) == "10 hours ago"
      assert last_used_humanize(user, twenty_seven_hours_ago) == "Yesterday"
      assert last_used_humanize(user, fifty_hours_ago) == "2 days ago"
      assert last_used_humanize(user, ten_days_ago) == "10 days ago"
    end
  end

  describe "get_by_token/1" do
    setup do
      user = new_user()

      session =
        user
        |> Auth.UserSession.new_session("A Device")
        |> Repo.insert!()

      {:ok, user: user, session: session}
    end

    test "fetches token by session", %{session: session, user: user} do
      user |> subscribe_to_growth_plan()
      team = team_of(user)
      assert {:ok, fetched} = UserSessions.get_by_token(session.token)

      assert fetched.id == session.id
      assert fetched.user.id == user.id
      assert [ownership] = fetched.user.team_memberships
      assert ownership.role == :owner
      assert ownership.team.id == team.id
      assert ownership.team.subscription.id
      assert [owner] = ownership.team.owners
      assert owner.id == user.id
    end

    test "returns not found when no matching session found" do
      assert {:error, :not_found} = UserSessions.get_by_token(Ecto.UUID.generate())
    end

    test "returns expired when the matching session is expired", %{session: session} do
      now = NaiveDateTime.utc_now(:second)
      in_the_past = NaiveDateTime.add(now, -1, :hour)
      session = session |> Ecto.Changeset.change(timeout_at: in_the_past) |> Repo.update!()

      assert {:error, :expired, expired_session} = UserSessions.get_by_token(session.token)
      assert expired_session.id == session.id
    end
  end

  describe "touch/1,2" do
    setup do
      user = new_user()

      session =
        user
        |> Auth.UserSession.new_session("A Device")
        |> Repo.insert!()

      {:ok, user: user, session: session}
    end

    test "refreshes user session timestamps", %{user: user, session: session} do
      two_days_later =
        NaiveDateTime.utc_now(:second)
        |> NaiveDateTime.shift(day: 2)

      assert refreshed_session =
               %Auth.UserSession{} = UserSessions.touch(session, two_days_later)

      assert refreshed_session.id == session.id
      assert NaiveDateTime.compare(refreshed_session.last_used_at, two_days_later) == :eq
      assert NaiveDateTime.compare(Repo.reload(user).last_seen, two_days_later) == :eq
      assert NaiveDateTime.compare(refreshed_session.timeout_at, session.timeout_at) == :gt
    end

    test "does not refresh if timestamps were updated less than hour before", %{
      user: user,
      session: session
    } do
      last_seen = Repo.reload(user).last_seen

      fifty_minutes_later =
        NaiveDateTime.utc_now(:second)
        |> NaiveDateTime.shift(minute: 50)

      assert refreshed_session1 =
               %Auth.UserSession{} =
               UserSessions.touch(session, fifty_minutes_later)

      assert NaiveDateTime.compare(
               refreshed_session1.last_used_at,
               session.last_used_at
             ) == :eq

      assert NaiveDateTime.compare(Repo.reload(user).last_seen, last_seen) == :eq

      sixty_five_minutes_later =
        NaiveDateTime.utc_now(:second)
        |> NaiveDateTime.shift(minute: 65)

      assert refreshed_session2 =
               %Auth.UserSession{} =
               UserSessions.touch(session, sixty_five_minutes_later)

      assert NaiveDateTime.compare(
               refreshed_session2.last_used_at,
               sixty_five_minutes_later
             ) == :eq

      assert NaiveDateTime.compare(Repo.reload(user).last_seen, sixty_five_minutes_later) == :eq
    end

    test "handles concurrent refresh gracefully", %{session: session} do
      # concurrent update
      now = NaiveDateTime.utc_now(:second)
      two_days_later = NaiveDateTime.shift(now, day: 2)

      Repo.update_all(
        from(us in Auth.UserSession, where: us.token == ^session.token),
        set: [timeout_at: two_days_later, last_used_at: now]
      )

      assert refreshed_session = %Auth.UserSession{} = UserSessions.touch(session)

      assert refreshed_session.id == session.id
      assert Repo.reload(session)
    end

    test "handles deleted session case gracefully", %{session: session} do
      Repo.delete!(session)

      assert refreshed_session = %Auth.UserSession{} = UserSessions.touch(session)

      assert refreshed_session.id == session.id

      refute Repo.reload(session)
    end

    on_ee do
      test "only records last usage but does not refresh for SSO user", %{
        user: user,
        session: session
      } do
        sixty_five_minutes_later =
          NaiveDateTime.utc_now(:second)
          |> NaiveDateTime.shift(minute: 65)

        user |> Ecto.Changeset.change(type: :sso) |> Repo.update!()

        session = Repo.reload!(session)

        assert refreshed_session =
                 %Auth.UserSession{} =
                 UserSessions.touch(session, sixty_five_minutes_later)

        assert refreshed_session.id == session.id

        assert NaiveDateTime.compare(refreshed_session.last_used_at, sixty_five_minutes_later) ==
                 :eq

        assert NaiveDateTime.compare(refreshed_session.timeout_at, session.timeout_at) == :eq
      end
    end
  end

  describe "revoke_by_id/2" do
    setup do
      user = new_user()

      session =
        user
        |> Auth.UserSession.new_session("A Device")
        |> Repo.insert!()

      {:ok, user: user, session: session}
    end

    test "deletes and disconnects user session", %{user: user, session: active_session} do
      live_socket_id = "user_sessions:" <> Base.url_encode64(active_session.token)
      Phoenix.PubSub.subscribe(Plausible.PubSub, live_socket_id)

      another_session =
        user
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      assert :ok = UserSessions.revoke_by_id(user, active_session.id)

      assert [remaining_session] = Repo.preload(user, :sessions).sessions
      assert_broadcast "disconnect", %{}
      assert remaining_session.id == another_session.id
      refute Repo.reload(active_session)
      assert Repo.reload(another_session)
    end

    test "does not delete session of another user", %{user: user, session: active_session} do
      other_session =
        insert(:user)
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      assert :ok = UserSessions.revoke_by_id(user, other_session.id)

      assert Repo.reload(active_session)
      assert Repo.reload(other_session)
    end

    test "executes gracefully when session does not exist", %{user: user, session: active_session} do
      Repo.delete!(active_session)

      assert :ok = UserSessions.revoke_by_id(user, active_session.id)
    end
  end

  describe "revoke_all/1,2" do
    setup do
      user = new_user()

      session =
        user
        |> Auth.UserSession.new_session("A Device")
        |> Repo.insert!()

      {:ok, user: user, session: session}
    end

    test "deletes and disconnects all user's sessions", %{user: user, session: active_session} do
      live_socket_id = "user_sessions:" <> Base.url_encode64(active_session.token)
      Phoenix.PubSub.subscribe(Plausible.PubSub, live_socket_id)

      another_session =
        user
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      unrelated_session =
        insert(:user)
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      assert :ok = UserSessions.revoke_all(user)

      assert [] = Repo.preload(user, :sessions).sessions
      assert_broadcast "disconnect", %{}
      refute Repo.reload(another_session)
      assert Repo.reload(unrelated_session)
    end

    test "executes gracefully when user has no sessions" do
      user = insert(:user)

      assert :ok = UserSessions.revoke_all(user)
    end
  end

  defp last_used_humanize(user, dt) do
    user
    |> insert_session("Some Device", dt)
    |> UserSessions.last_used_humanize()
  end

  defp insert_session(user, device_name, now) do
    user
    |> Auth.UserSession.new_session(device_name, now: now)
    |> Repo.insert!()
  end
end
