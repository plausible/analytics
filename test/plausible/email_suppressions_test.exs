defmodule Plausible.EmailSuppressionsTest do
  use Plausible.DataCase

  alias Plausible.EmailSuppressions
  alias Plausible.Postmark

  @moduletag :ee_only

  # Suppressions without Bounce ID (backfilled)
  # go through delete suppressions API call on reactivate.
  # Tests that expect different result may override this.
  setup do
    Req.Test.stub(Postmark, fn conn ->
      Req.Test.json(conn, %{
        "Message" => "OK",
        "Suppressions" => [%{"Status" => "Deleted"}]
      })
    end)

    :ok
  end

  defp touch_updated_at(suppression, naive_datetime) do
    suppression
    |> Ecto.Changeset.change(updated_at: naive_datetime)
    |> Repo.update!()
  end

  describe "suppressed?/1" do
    test "false when no record exists" do
      refute EmailSuppressions.suppressed?("nobody@example.com")
    end

    test "true after a bounce is recorded" do
      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "bounced@example.com",
          reason: :hard_bounce,
          source: :webhook,
          postmark_bounce_id: 123,
          postmark_inactive: true,
          can_activate: true,
          details: "Unknown user"
        })

      assert EmailSuppressions.suppressed?("bounced@example.com")
    end

    test "is case-insensitive" do
      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "Bounced@Example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      assert EmailSuppressions.suppressed?("bounced@example.com")
    end

    test "false again after reactivation" do
      user = insert(:user)

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "bounced@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      assert {:ok, _} = EmailSuppressions.reactivate("bounced@example.com", user)
      refute EmailSuppressions.suppressed?("bounced@example.com")
    end
  end

  describe "create_from_bounce/1" do
    test "requires email, reason and source" do
      assert {:error, changeset} = EmailSuppressions.create_from_bounce(%{})

      assert {"can't be blank", _} = changeset.errors[:email]
      assert {"can't be blank", _} = changeset.errors[:reason]
      assert {"can't be blank", _} = changeset.errors[:source]
    end

    test "refreshes the existing record instead of failing on duplicate email" do
      {:ok, first} =
        EmailSuppressions.create_from_bounce(%{
          email: "bounced@example.com",
          reason: :hard_bounce,
          source: :webhook,
          postmark_bounce_id: 1
        })

      {:ok, second} =
        EmailSuppressions.create_from_bounce(%{
          email: "bounced@example.com",
          reason: :blocked,
          source: :webhook,
          postmark_bounce_id: 2
        })

      assert first.id == second.id
      assert second.reason == :blocked
      assert second.postmark_bounce_id == 2
    end

    test "a fresh bounce re-suppresses a previously reactivated address" do
      user = insert(:user)

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "bounced@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _} = EmailSuppressions.reactivate("bounced@example.com", user)
      refute EmailSuppressions.suppressed?("bounced@example.com")

      {:ok, suppression} =
        EmailSuppressions.create_from_bounce(%{
          email: "bounced@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      assert EmailSuppressions.suppressed?("bounced@example.com")
      assert is_nil(suppression.reactivated_at)
      assert is_nil(suppression.reactivated_by_user_id)
    end

    test "a bounce webhook clears a reactivation left by an earlier, different webhook" do
      user = insert(:user)

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "flip-flop@example.com",
          reason: :blocked,
          source: :webhook
        })

      {:ok, _} = EmailSuppressions.reactivate("flip-flop@example.com", user)
      refute EmailSuppressions.suppressed?("flip-flop@example.com")

      {:ok, suppression} =
        EmailSuppressions.create_from_bounce(%{
          email: "flip-flop@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      assert EmailSuppressions.suppressed?("flip-flop@example.com")
      assert suppression.reason == :hard_bounce
      assert is_nil(suppression.reactivated_at)
      assert is_nil(suppression.reactivated_by_user_id)
    end
  end

  describe "create_from_spam_complaint/1" do
    test "sets reason to :spam_complaint" do
      {:ok, suppression} =
        EmailSuppressions.create_from_spam_complaint(%{
          email: "complainer@example.com",
          source: :webhook
        })

      assert suppression.reason == :spam_complaint
      assert EmailSuppressions.suppressed?("complainer@example.com")
    end

    test "a spam complaint webhook clears a reactivation left by an earlier bounce" do
      user = insert(:user)

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "flip-flop@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _} = EmailSuppressions.reactivate("flip-flop@example.com", user)
      refute EmailSuppressions.suppressed?("flip-flop@example.com")

      {:ok, suppression} =
        EmailSuppressions.create_from_spam_complaint(%{
          email: "flip-flop@example.com",
          source: :webhook
        })

      assert EmailSuppressions.suppressed?("flip-flop@example.com")
      assert suppression.reason == :spam_complaint
      assert is_nil(suppression.reactivated_at)
      assert is_nil(suppression.reactivated_by_user_id)
    end
  end

  describe "list/1" do
    setup do
      {:ok, hard} =
        EmailSuppressions.create_from_bounce(%{
          email: "hard@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _blocked} =
        EmailSuppressions.create_from_bounce(%{
          email: "blocked@example.com",
          reason: :blocked,
          source: :backfill
        })

      %{hard: hard}
    end

    test "returns everything, most recently suppressed first" do
      assert %{entries: entries} = EmailSuppressions.list()

      assert Enum.map(entries, & &1.email) == ["blocked@example.com", "hard@example.com"]
    end

    test "filters by reason" do
      assert %{entries: [suppression]} = EmailSuppressions.list(reason: :blocked)

      assert suppression.email == "blocked@example.com"
    end

    test "filters by an email substring, case-insensitively" do
      assert %{entries: [suppression]} = EmailSuppressions.list(search: "HARD@")

      assert suppression.email == "hard@example.com"
    end

    test "paginates via before/after cursors" do
      assert %{entries: [first], metadata: %{after: cursor, before: nil}} =
               EmailSuppressions.list([], %{"limit" => "1"})

      assert first.email == "blocked@example.com"

      assert %{entries: [second], metadata: %{after: nil}} =
               EmailSuppressions.list([], %{"limit" => "1", "after" => cursor})

      assert second.email == "hard@example.com"
    end
  end

  describe "create_from_unsubscribe/1" do
    test "sets reason to :unsubscribe" do
      {:ok, suppression} =
        EmailSuppressions.create_from_unsubscribe(%{
          email: "unsubscribed@example.com",
          source: :webhook,
          details: "Unsubscribed via Postmark (origin: Recipient)"
        })

      assert suppression.reason == :unsubscribe
      assert suppression.details == "Unsubscribed via Postmark (origin: Recipient)"
      assert EmailSuppressions.suppressed?("unsubscribed@example.com")
    end

    test "an unsubscribe webhook clears a reactivation left by an earlier bounce" do
      user = insert(:user)

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "flip-flop@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _} = EmailSuppressions.reactivate("flip-flop@example.com", user)
      refute EmailSuppressions.suppressed?("flip-flop@example.com")

      {:ok, suppression} =
        EmailSuppressions.create_from_unsubscribe(%{
          email: "flip-flop@example.com",
          source: :webhook
        })

      assert EmailSuppressions.suppressed?("flip-flop@example.com")
      assert suppression.reason == :unsubscribe
      assert is_nil(suppression.reactivated_at)
      assert is_nil(suppression.reactivated_by_user_id)
    end
  end

  describe "create_from_rejected_send/1" do
    test "sets reason to :recipient_rejected and source to :rejected" do
      {:ok, suppression} =
        EmailSuppressions.create_from_rejected_send(%{
          email: "rejected@example.com",
          details: "Rejected by Postmark on send: some reason"
        })

      assert suppression.reason == :recipient_rejected
      assert suppression.source == :rejected
      assert suppression.details == "Rejected by Postmark on send: some reason"
      assert EmailSuppressions.suppressed?("rejected@example.com")
    end

    test "a rejected send clears a reactivation left by an earlier bounce" do
      user = insert(:user)

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "flip-flop@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _} = EmailSuppressions.reactivate("flip-flop@example.com", user)
      refute EmailSuppressions.suppressed?("flip-flop@example.com")

      {:ok, suppression} =
        EmailSuppressions.create_from_rejected_send(%{email: "flip-flop@example.com"})

      assert EmailSuppressions.suppressed?("flip-flop@example.com")
      assert suppression.reason == :recipient_rejected
      assert is_nil(suppression.reactivated_at)
      assert is_nil(suppression.reactivated_by_user_id)
    end
  end

  describe "list_orphaned/2" do
    test "returns a suppression with no matching user, invitation or transfer, stale enough" do
      {:ok, suppression} =
        EmailSuppressions.create_from_bounce(%{
          email: "orphaned@example.com",
          reason: :hard_bounce,
          source: :backfill
        })

      touch_updated_at(
        suppression,
        NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: -15)
      )

      assert [%{email: "orphaned@example.com"}] =
               EmailSuppressions.list_orphaned(Duration.new!(day: -14), 100)
    end

    test "excludes a suppression that isn't stale enough yet" do
      {:ok, suppression} =
        EmailSuppressions.create_from_bounce(%{
          email: "fresh@example.com",
          reason: :hard_bounce,
          source: :backfill
        })

      touch_updated_at(
        suppression,
        NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: -13)
      )

      assert EmailSuppressions.list_orphaned(Duration.new!(day: -14), 100) == []
    end

    test "excludes a suppression matching an existing user's email" do
      user = insert(:user, email: "still-a-user@example.com")

      {:ok, suppression} =
        EmailSuppressions.create_from_bounce(%{
          email: user.email,
          reason: :hard_bounce,
          source: :backfill
        })

      touch_updated_at(
        suppression,
        NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: -15)
      )

      assert EmailSuppressions.list_orphaned(Duration.new!(day: -14), 100) == []
    end

    test "excludes a suppression matching a pending team invitation's email" do
      owner = insert(:user)
      {:ok, team} = Plausible.Teams.get_or_create(owner)

      insert(:team_invitation,
        team: team,
        inviter: owner,
        email: "invited@example.com",
        role: :guest
      )

      {:ok, suppression} =
        EmailSuppressions.create_from_bounce(%{
          email: "invited@example.com",
          reason: :hard_bounce,
          source: :backfill
        })

      touch_updated_at(
        suppression,
        NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: -15)
      )

      assert EmailSuppressions.list_orphaned(Duration.new!(day: -14), 100) == []
    end

    test "excludes a suppression matching a pending site transfer's email" do
      owner = new_user()
      site = new_site(owner: owner)

      insert(:site_transfer, email: "transferee@example.com", site: site, initiator: owner)

      {:ok, suppression} =
        EmailSuppressions.create_from_bounce(%{
          email: "transferee@example.com",
          reason: :hard_bounce,
          source: :backfill
        })

      touch_updated_at(
        suppression,
        NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: -15)
      )

      assert EmailSuppressions.list_orphaned(Duration.new!(day: -14), 100) == []
    end

    test "matches case-insensitively, since all relevant email columns are citext" do
      insert(:user, email: "MixedCase@Example.com")

      {:ok, suppression} =
        EmailSuppressions.create_from_bounce(%{
          email: "mixedcase@example.com",
          reason: :hard_bounce,
          source: :backfill
        })

      touch_updated_at(
        suppression,
        NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: -15)
      )

      assert EmailSuppressions.list_orphaned(Duration.new!(day: -14), 100) == []
    end

    test "returns the oldest candidates first, bounded by limit" do
      now = NaiveDateTime.utc_now(:second)

      for n <- 1..3 do
        {:ok, suppression} =
          EmailSuppressions.create_from_bounce(%{
            email: "orphan-#{n}@example.com",
            reason: :hard_bounce,
            source: :backfill
          })

        touch_updated_at(suppression, NaiveDateTime.shift(now, day: -20 + n))
      end

      assert [%{email: "orphan-1@example.com"}] =
               EmailSuppressions.list_orphaned(Duration.new!(day: -14), 1)
    end
  end

  describe "delete_all/1" do
    test "removes exactly the given suppressions" do
      {:ok, keep} =
        EmailSuppressions.create_from_bounce(%{
          email: "keep@example.com",
          reason: :hard_bounce,
          source: :backfill
        })

      {:ok, remove} =
        EmailSuppressions.create_from_bounce(%{
          email: "remove@example.com",
          reason: :hard_bounce,
          source: :backfill
        })

      assert EmailSuppressions.delete_all([remove]) == 1

      assert Repo.get(Plausible.EmailSuppression, keep.id)
      refute Repo.get(Plausible.EmailSuppression, remove.id)
    end

    test "returns 0 for an empty list" do
      assert EmailSuppressions.delete_all([]) == 0
    end
  end

  describe "reactivate/2" do
    test "returns :not_found when there is no suppression for the address" do
      user = insert(:user)
      assert {:error, :not_found} = EmailSuppressions.reactivate("nobody@example.com", user)
    end

    test "records who reactivated it" do
      user = insert(:user)

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "bounced@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      assert {:ok, suppression} = EmailSuppressions.reactivate("bounced@example.com", user)
      assert suppression.reactivated_by_user_id == user.id
      assert suppression.reactivated_at
    end

    test "deletes the suppression in Postmark" do
      user = insert(:user)

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "bounced@example.com",
          reason: :hard_bounce,
          source: :backfill
        })

      Req.Test.stub(Postmark, fn conn ->
        assert conn.method == "POST"

        assert conn.request_path in [
                 "/message-streams/outbound/suppressions/delete",
                 "/message-streams/priority/suppressions/delete"
               ]

        Req.Test.json(conn, %{
          "Suppressions" => [%{"EmailAddress" => "bounced@example.com", "Status" => "Deleted"}]
        })
      end)

      assert {:ok, _suppression} = EmailSuppressions.reactivate("bounced@example.com", user)
      refute EmailSuppressions.suppressed?("bounced@example.com")
    end

    test "refuses to reactivate a spam complaint, leaving it suppressed" do
      user = insert(:user)

      {:ok, _} =
        EmailSuppressions.create_from_spam_complaint(%{
          email: "complainer@example.com",
          source: :backfill
        })

      Req.Test.stub(Postmark, fn _conn -> flunk("Postmark should not have been called") end)

      assert {:error, :cannot_delete_spam_complaint} =
               EmailSuppressions.reactivate("complainer@example.com", user)

      assert EmailSuppressions.suppressed?("complainer@example.com")
    end

    test "leaves it suppressed when the Postmark deletion call fails" do
      user = insert(:user)

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "bounced@example.com",
          reason: :hard_bounce,
          source: :backfill
        })

      Req.Test.stub(Postmark, fn conn ->
        conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"Message" => "boom"})
      end)

      assert {:error, {:postmark_error, _reason}} =
               EmailSuppressions.reactivate("bounced@example.com", user)

      assert EmailSuppressions.suppressed?("bounced@example.com")
    end
  end
end
