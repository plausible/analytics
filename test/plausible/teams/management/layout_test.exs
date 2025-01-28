defmodule Plausible.Teams.Management.LayoutTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test
  use Bamboo.Test
  use Plausible

  alias Plausible.Teams.Management.Layout
  alias Plausible.Teams.Management.Layout.Entry
  alias Plausible.Teams

  describe "no persistence" do
    test "can be built of invitations and memberships" do
      layout = sample_layout()

      assert %Entry{name: "Current User", label: "You", role: :admin, type: :membership} =
               layout["current@example.com"]

      assert %Entry{name: "Owner User", label: "Team Member", role: :owner, type: :membership} =
               layout["owner@example.com"]

      assert %Entry{
               name: "Invited User",
               label: "Invitation Sent",
               role: :admin,
               type: :invitation_sent
             } =
               layout["invitation-sent@example.com"]

      assert %Entry{
               name: "Invited User",
               label: "Invitation Pending",
               role: :admin,
               type: :invitation_pending
             } =
               layout["invitation-pending@example.com"]
    end

    test "can be sorted for display" do
      layout =
        sample_layout()

      assert [
               {"invitation-pending@example.com", %Entry{}},
               {"invitation-sent@example.com", %Entry{}},
               {"current@example.com", %Entry{}},
               {"owner@example.com", %Entry{}}
             ] = Layout.sorted_for_display(layout)

      layout =
        layout
        |> Layout.put(
          membership(name: "Aa", email: "00-invitation-accepted@example.com", role: :viewer)
        )
        |> Layout.put(invitation_pending("00-invitation-pending@example.com"))
        |> Layout.put(invitation_sent("00-invitation-sent@example.com"))

      assert [
               {"00-invitation-pending@example.com", %Entry{}},
               {"invitation-pending@example.com", %Entry{}},
               {"00-invitation-sent@example.com", %Entry{}},
               {"invitation-sent@example.com", %Entry{}},
               {"00-invitation-accepted@example.com", %Entry{}},
               {"current@example.com", %Entry{}},
               {"owner@example.com", %Entry{}}
             ] = Layout.sorted_for_display(layout)
    end

    test "removable?/2" do
      layout = sample_layout()
      assert Layout.removable?(layout, "invitation-pending@example.com")
      assert Layout.removable?(layout, "current@example.com")
      refute Layout.removable?(layout, "owner@example.com")

      layout =
        Layout.put(
          layout,
          invitation_sent("maybe-owner@example.com", role: :owner)
        )

      refute Layout.removable?(layout, "owner@example.com")

      layout =
        Layout.put(
          layout,
          membership(
            email: "secondary-owner@example.com",
            role: :owner
          )
        )

      assert Layout.removable?(layout, "owner@example.com")
      assert Layout.removable?(layout, "secondary-owner@example.com")

      layout = Layout.schedule_delete(layout, "owner@example.com")

      refute Layout.removable?(layout, "secondary-owner@example.com")
    end

    test "update_role/3" do
      assert %Entry{queued_op: :update, role: :owner} =
               sample_layout()
               |> Layout.update_role("current@example.com", :owner)
               |> Layout.get("current@example.com")

      assert_raise KeyError, ~r/not found/, fn ->
        Layout.update_role(sample_layout(), "x", :owner)
      end
    end

    test "schedule_send/3" do
      assert %Entry{
               queued_op: :send,
               name: "Invited User",
               role: :admin,
               meta: %{email: "new@example.com"}
             } =
               sample_layout()
               |> Layout.schedule_send("new@example.com", :admin)
               |> Layout.get("new@example.com")

      assert %Entry{
               queued_op: :send,
               name: "Joe Doe",
               role: :admin,
               meta: %{email: "new@example.com"}
             } =
               sample_layout()
               |> Layout.schedule_send("new@example.com", :admin, name: "Joe Doe")
               |> Layout.get("new@example.com")
    end

    test "schedule_delete/2" do
      assert %Entry{queued_op: :delete, label: "You"} =
               sample_layout()
               |> Layout.schedule_delete("current@example.com")
               |> Layout.get("current@example.com")

      assert_raise KeyError, ~r/not found/, fn ->
        Layout.schedule_delete(sample_layout(), "x")
      end
    end

    test "overwrite" do
      assert %Entry{queued_op: :send, label: "Invitation Pending"} =
               sample_layout()
               |> Layout.put(
                 membership(
                   name: "Aa",
                   email: "00-invitation-accepted@example.com",
                   role: :viewer
                 )
               )
               |> Layout.schedule_send("current@example.com", :admin)
               |> Layout.get("current@example.com")
    end

    defp invitation_pending(email) do
      build(:team_invitation, email: email)
    end

    defp invitation_sent(email, attrs \\ []) do
      build(
        :team_invitation,
        Keyword.merge(
          [email: email, id: Enum.random(1..1_000_000)],
          attrs
        )
      )
    end

    defp membership(attrs) do
      build(:team_membership,
        role: attrs[:role],
        user: attrs[:user] || build(:user, name: attrs[:name], email: attrs[:email])
      )
    end

    defp sample_layout() do
      current_user = build(:user, id: 777, name: "Current User", email: "current@example.com")

      input = [
        invitation_pending("invitation-pending@example.com"),
        membership(
          role: :owner,
          name: "Owner User",
          email: "owner@example.com"
        ),
        membership(role: :admin, user: current_user),
        invitation_sent("invitation-sent@example.com")
      ]

      Layout.build_by_email(input, current_user)
    end
  end

  describe "persistence" do
    @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "
    setup [:create_user, :create_team]

    test "unchanged layout no-op", %{user: user, team: team} do
      add_member(team, role: :admin)
      invite_member(team, "invite@example.com", role: :viewer, inviter: user)

      assert {:ok, 0} =
               user
               |> layout_from_db(team)
               |> Layout.persist(%{current_user: user, my_team: team})

      assert_no_emails_delivered()
    end

    test "invitation pending email goes out", %{user: user, team: team} do
      assert {:ok, 1} =
               user
               |> layout_from_db(team)
               |> Layout.schedule_send("test@example.com", :admin)
               |> Layout.persist(%{current_user: user, my_team: team})

      assert_email_delivered_with(
        to: [nil: "test@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )

      layout = layout_from_db(user, team)
      assert %{type: :invitation_sent} = Layout.get(layout, "test@example.com")
    end

    test "membership removal email goes out", %{user: user, team: team} do
      add_member(team, role: :admin, user: new_user(email: "test@example.com"))

      assert {:ok, 1} =
               user
               |> layout_from_db(team)
               |> Layout.schedule_delete("test@example.com")
               |> Layout.persist(%{current_user: user, my_team: team})

      assert_email_delivered_with(
        to: [nil: "test@example.com"],
        subject: @subject_prefix <> "Your access to \"#{team.name}\" team has been revoked"
      )
    end

    test "limits are checked", %{user: user, team: team} do
      assert {:error, {:over_limit, 3}} =
               user
               |> layout_from_db(team)
               |> Layout.schedule_send("test1@example.com", :admin)
               |> Layout.schedule_send("test2@example.com", :admin)
               |> Layout.schedule_send("test3@example.com", :admin)
               |> Layout.schedule_send("test4@example.com", :admin)
               |> Layout.persist(%{current_user: user, my_team: team})

      assert_no_emails_delivered()
    end

    test "deletions are made first, so that limits apply accurately", %{user: user, team: team} do
      add_member(team, role: :admin, user: new_user(email: "test1@example.com"))
      add_member(team, role: :admin, user: new_user(email: "test2@example.com"))
      add_member(team, role: :admin, user: new_user(email: "test3@example.com"))

      assert {:ok, 3} =
               user
               |> layout_from_db(team)
               |> Layout.schedule_send("new@example.com", :admin)
               |> Layout.schedule_delete("test1@example.com")
               |> Layout.schedule_delete("test2@example.com")
               |> Layout.persist(%{current_user: user, my_team: team})
    end

    test "multiple ops queue", %{user: user, team: team} do
      member1 = add_member(team, role: :admin, user: new_user(email: "test1@example.com"))
      member2 = add_member(team, role: :admin, user: new_user(email: "test2@example.com"))

      assert {:ok, 3} =
               user
               |> layout_from_db(team)
               |> Layout.schedule_send("new@example.com", :admin)
               |> Layout.schedule_delete("test1@example.com")
               |> Layout.update_role("test2@example.com", :viewer)
               |> Layout.persist(%{current_user: user, my_team: team})

      assert {:error, :not_a_member} = Teams.Memberships.team_role(team, member1)
      assert {:ok, :viewer} = Teams.Memberships.team_role(team, member2)
      assert [%{email: "new@example.com"}] = Teams.Invitations.find_team_invitations(team)

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )

      assert_email_delivered_with(
        to: [nil: "test1@example.com"],
        subject: @subject_prefix <> "Your access to \"#{team.name}\" team has been revoked"
      )

      assert_no_emails_delivered()
    end

    test "deletion of scheduled invitations is no-op", %{user: user, team: team} do
      assert {:ok, 0} =
               user
               |> layout_from_db(team)
               |> Layout.schedule_send("new@example.com", :admin)
               |> Layout.schedule_delete("new@example.com")
               |> Layout.persist(%{current_user: user, my_team: team})
    end

    test "idempotence", %{user: user, team: team} do
      add_member(team, role: :admin, user: new_user(email: "test1@example.com"))
      add_member(team, role: :admin, user: new_user(email: "test2@example.com"))

      assert {:ok, 3} =
               user
               |> layout_from_db(team)
               |> Layout.schedule_send("new@example.com", :admin)
               |> Layout.schedule_delete("test1@example.com")
               |> Layout.schedule_send("new@example.com", :admin)
               |> Layout.update_role("test2@example.com", :viewer)
               |> Layout.schedule_delete("test1@example.com")
               |> Layout.update_role("test2@example.com", :viewer)
               |> Layout.persist(%{current_user: user, my_team: team})

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )

      assert_email_delivered_with(
        to: [nil: "test1@example.com"],
        subject: @subject_prefix <> "Your access to \"#{team.name}\" team has been revoked"
      )

      assert_no_emails_delivered()
    end

    defp layout_from_db(user, team) do
      Layout.init(team, user)
    end
  end
end
