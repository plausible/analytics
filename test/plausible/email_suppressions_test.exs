defmodule Plausible.EmailSuppressionsTest do
  use Plausible.DataCase

  alias Plausible.EmailSuppressions

  @moduletag :ee_only

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
        EmailSuppressions.create_from_spam_complaint(%{
          email: "flip-flop@example.com",
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
  end
end
