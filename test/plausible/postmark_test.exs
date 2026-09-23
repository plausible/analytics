defmodule Plausible.PostmarkTest do
  use Plausible.DataCase, async: true
  @moduletag :ee_only
  @moduletag :capture_log

  alias Plausible.EmailSuppressions
  alias Plausible.Postmark

  describe "suppressing_reason/1" do
    test "maps known permanently-bad bounce types" do
      assert Postmark.suppressing_reason("HardBounce") == {:ok, :hard_bounce}
      assert Postmark.suppressing_reason("BadEmailAddress") == {:ok, :bad_email_address}
      assert Postmark.suppressing_reason("Blocked") == {:ok, :blocked}
      assert Postmark.suppressing_reason("SpamNotification") == {:ok, :spam_notification}
      assert Postmark.suppressing_reason("Unsubscribe") == {:ok, :unsubscribe}
    end

    test "does not map transient bounce types" do
      assert Postmark.suppressing_reason("Transient") == :error
      assert Postmark.suppressing_reason("SpamComplaint") == :error
      assert Postmark.suppressing_reason("SomethingUnknown") == :error
    end
  end

  describe "backfill_suppressions/0" do
    test "upserts a suppression for every entry found, across both streams" do
      Req.Test.stub(Postmark, fn conn ->
        entries =
          case conn.request_path do
            "/message-streams/outbound/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "hard@example.com",
                  "SuppressionReason" => "HardBounce",
                  "Origin" => "Recipient"
                },
                %{
                  "EmailAddress" => "complainer@example.com",
                  "SuppressionReason" => "SpamComplaint",
                  "Origin" => "Recipient"
                }
              ]

            "/message-streams/priority/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "manual@example.com",
                  "SuppressionReason" => "ManualSuppression",
                  "Origin" => "Admin"
                }
              ]
          end

        Req.Test.json(conn, %{"Suppressions" => entries})
      end)

      assert %{processed: 3, distinct_addresses: 3, upsert_errors: 0, fetch_errors: 0} =
               Postmark.backfill_suppressions()

      assert EmailSuppressions.suppressed?("hard@example.com")
      assert EmailSuppressions.suppressed?("complainer@example.com")
      assert EmailSuppressions.suppressed?("manual@example.com")

      hard = Repo.get_by!(Plausible.EmailSuppression, email: "hard@example.com")
      assert hard.reason == :hard_bounce
      assert hard.source == :backfill
      assert hard.details == "Postmark suppression (origin: Recipient)"

      complainer = Repo.get_by!(Plausible.EmailSuppression, email: "complainer@example.com")
      assert complainer.reason == :spam_complaint

      manual = Repo.get_by!(Plausible.EmailSuppression, email: "manual@example.com")
      assert manual.reason == :manual
    end

    test "maps a recipient-originated ManualSuppression to :unsubscribe" do
      Req.Test.stub(Postmark, fn conn ->
        entries =
          case conn.request_path do
            "/message-streams/outbound/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "unsubscribed@example.com",
                  "SuppressionReason" => "ManualSuppression",
                  "Origin" => "Recipient"
                }
              ]

            "/message-streams/priority/suppressions/dump" ->
              []
          end

        Req.Test.json(conn, %{"Suppressions" => entries})
      end)

      assert %{upsert_errors: 0} = Postmark.backfill_suppressions()

      suppression = Repo.get_by!(Plausible.EmailSuppression, email: "unsubscribed@example.com")
      assert suppression.reason == :unsubscribe
    end

    test "maps a customer/admin-originated ManualSuppression to :manual" do
      Req.Test.stub(Postmark, fn conn ->
        entries =
          case conn.request_path do
            "/message-streams/outbound/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "suppressed-by-admin@example.com",
                  "SuppressionReason" => "ManualSuppression",
                  "Origin" => "Customer"
                }
              ]

            "/message-streams/priority/suppressions/dump" ->
              []
          end

        Req.Test.json(conn, %{"Suppressions" => entries})
      end)

      assert %{upsert_errors: 0} = Postmark.backfill_suppressions()

      suppression =
        Repo.get_by!(Plausible.EmailSuppression, email: "suppressed-by-admin@example.com")

      assert suppression.reason == :manual
    end

    test "counts fetch failures separately, per stream" do
      Req.Test.stub(Postmark, fn conn ->
        case conn.request_path do
          "/message-streams/outbound/suppressions/dump" ->
            conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"Message" => "boom"})

          "/message-streams/priority/suppressions/dump" ->
            Req.Test.json(conn, %{"Suppressions" => []})
        end
      end)

      assert %{processed: 0, distinct_addresses: 0, upsert_errors: 0, fetch_errors: 1} =
               Postmark.backfill_suppressions()
    end

    test "counts distinct_addresses, deduping the same address across streams" do
      Req.Test.stub(Postmark, fn conn ->
        entry = %{
          "EmailAddress" => "repeat@example.com",
          "SuppressionReason" => "HardBounce",
          "Origin" => "Recipient"
        }

        Req.Test.json(conn, %{"Suppressions" => [entry]})
      end)

      assert %{processed: 2, distinct_addresses: 1, upsert_errors: 0, fetch_errors: 0} =
               Postmark.backfill_suppressions()

      assert EmailSuppressions.suppressed?("repeat@example.com")
      assert Repo.aggregate(Plausible.EmailSuppression, :count) == 1
    end

    test "counts email citext variants as the same address" do
      Req.Test.stub(Postmark, fn conn ->
        entries =
          case conn.request_path do
            "/message-streams/outbound/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "Mixed.Case@Example.com",
                  "SuppressionReason" => "HardBounce",
                  "Origin" => "Recipient"
                }
              ]

            "/message-streams/priority/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "mixed.case@example.com",
                  "SuppressionReason" => "HardBounce",
                  "Origin" => "Recipient"
                }
              ]
          end

        Req.Test.json(conn, %{"Suppressions" => entries})
      end)

      assert %{processed: 2, distinct_addresses: 1, upsert_errors: 0, fetch_errors: 0} =
               Postmark.backfill_suppressions()

      assert Repo.aggregate(Plausible.EmailSuppression, :count) == 1
    end

    test "for multiple entries, the most recent one wins" do
      Req.Test.stub(Postmark, fn conn ->
        entries =
          case conn.request_path do
            "/message-streams/outbound/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "flip@example.com",
                  "SuppressionReason" => "HardBounce",
                  "Origin" => "Recipient",
                  "CreatedAt" => "2026-01-01T00:00:00Z"
                }
              ]

            "/message-streams/priority/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "flip@example.com",
                  "SuppressionReason" => "ManualSuppression",
                  "Origin" => "Admin",
                  "CreatedAt" => "2026-06-01T00:00:00Z"
                }
              ]
          end

        Req.Test.json(conn, %{"Suppressions" => entries})
      end)

      assert %{distinct_addresses: 1} = Postmark.backfill_suppressions()

      suppression = Repo.get_by!(Plausible.EmailSuppression, email: "flip@example.com")
      assert suppression.reason == :manual
      assert suppression.details == "Postmark suppression (origin: Admin)"
    end

    test "spam complaint always wins over another reason" do
      Req.Test.stub(Postmark, fn conn ->
        entries =
          case conn.request_path do
            "/message-streams/outbound/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "complained@example.com",
                  "SuppressionReason" => "HardBounce",
                  "Origin" => "Recipient",
                  "CreatedAt" => "2026-06-01T00:00:00Z"
                }
              ]

            "/message-streams/priority/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "complained@example.com",
                  "SuppressionReason" => "SpamComplaint",
                  "Origin" => "Recipient",
                  "CreatedAt" => "2026-01-01T00:00:00Z"
                }
              ]
          end

        Req.Test.json(conn, %{"Suppressions" => entries})
      end)

      assert %{distinct_addresses: 1} = Postmark.backfill_suppressions()

      suppression = Repo.get_by!(Plausible.EmailSuppression, email: "complained@example.com")
      assert suppression.reason == :spam_complaint
    end

    test "a missing CreatedAt does not crash the backfill" do
      Req.Test.stub(Postmark, fn conn ->
        entries =
          case conn.request_path do
            "/message-streams/outbound/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "no-timestamp@example.com",
                  "SuppressionReason" => "HardBounce",
                  "Origin" => "Recipient"
                }
              ]

            "/message-streams/priority/suppressions/dump" ->
              []
          end

        Req.Test.json(conn, %{"Suppressions" => entries})
      end)

      assert %{distinct_addresses: 1, upsert_errors: 0} = Postmark.backfill_suppressions()
      assert EmailSuppressions.suppressed?("no-timestamp@example.com")
    end

    test "falls back to :manual for an unrecognized SuppressionReason" do
      Req.Test.stub(Postmark, fn conn ->
        entries =
          case conn.request_path do
            "/message-streams/outbound/suppressions/dump" ->
              [
                %{
                  "EmailAddress" => "unknown-reason@example.com",
                  "SuppressionReason" => "SomethingNew",
                  "Origin" => "Recipient"
                }
              ]

            "/message-streams/priority/suppressions/dump" ->
              []
          end

        Req.Test.json(conn, %{"Suppressions" => entries})
      end)

      assert %{upsert_errors: 0} = Postmark.backfill_suppressions()

      suppression = Repo.get_by!(Plausible.EmailSuppression, email: "unknown-reason@example.com")
      assert suppression.reason == :manual
    end
  end
end
