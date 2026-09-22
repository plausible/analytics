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
    end

    test "does not map transient bounce types" do
      assert Postmark.suppressing_reason("Transient") == :error
      assert Postmark.suppressing_reason("SpamComplaint") == :error
      assert Postmark.suppressing_reason("SomethingUnknown") == :error
    end
  end

  describe "suppressing_bounce_types/0" do
    test "returns the bounce type strings suppressing_reason/1 maps" do
      assert Enum.sort(Postmark.suppressing_bounce_types()) ==
               Enum.sort(["HardBounce", "BadEmailAddress", "Blocked", "SpamNotification"])
    end
  end

  describe "list_bounces/1" do
    test "returns bounces from a single page" do
      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["type"] == "HardBounce"
        assert conn.query_params["offset"] == "0"

        Req.Test.json(conn, %{
          "TotalCount" => 2,
          "Bounces" => [%{"Email" => "a@example.com"}, %{"Email" => "b@example.com"}]
        })
      end)

      assert {:ok, bounces} = Postmark.list_bounces(%{type: "HardBounce"})
      assert Enum.map(bounces, & &1["Email"]) == ["a@example.com", "b@example.com"]
    end

    test "pages until every bounce has been fetched" do
      page_size = 500

      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        {offset, ""} = Integer.parse(conn.query_params["offset"])

        bounces =
          if offset == 0 do
            List.duplicate(%{"Email" => "bounced@example.com"}, page_size)
          else
            [%{"Email" => "last@example.com"}]
          end

        Req.Test.json(conn, %{"TotalCount" => page_size + 1, "Bounces" => bounces})
      end)

      assert {:ok, bounces} = Postmark.list_bounces(%{type: "HardBounce"})
      assert length(bounces) == page_size + 1
      assert List.last(bounces)["Email"] == "last@example.com"
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Postmark, fn conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{"Message" => "Invalid type"})
      end)

      assert {:error, {:unexpected_status, 422, _body}} = Postmark.list_bounces(%{type: "Bogus"})
    end
  end

  describe "activate_bounce/1" do
    test "PUTs to the activate endpoint for the given bounce ID" do
      Req.Test.stub(Postmark, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/bounces/123/activate"
        Req.Test.json(conn, %{"Message" => "OK", "Bounce" => %{"ID" => 123, "Inactive" => false}})
      end)

      assert {:ok, %{"Message" => "OK"}} = Postmark.activate_bounce(123)
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Postmark, fn conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{"Message" => "Bounce cannot be activated"})
      end)

      assert {:error, {:unexpected_status, 422, _body}} = Postmark.activate_bounce(123)
    end
  end

  describe "backfill_suppressions/0" do
    test "upserts a suppression for every bounce and complaint found" do
      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        bounces =
          case conn.query_params["type"] do
            "HardBounce" -> [%{"Email" => "hard@example.com", "ID" => 1}]
            "BadEmailAddress" -> [%{"Email" => "bad@example.com", "ID" => 2}]
            "Blocked" -> [%{"Email" => "blocked@example.com", "ID" => 3}]
            "SpamComplaint" -> [%{"Email" => "complainer@example.com", "ID" => 4}]
            "SpamNotification" -> [%{"Email" => "spam-notified@example.com", "ID" => 5}]
          end

        Req.Test.json(conn, %{"TotalCount" => length(bounces), "Bounces" => bounces})
      end)

      assert %{processed: 5, distinct_addresses: 5, upsert_errors: 0, fetch_errors: 0} =
               Postmark.backfill_suppressions()

      assert EmailSuppressions.suppressed?("hard@example.com")
      assert EmailSuppressions.suppressed?("bad@example.com")
      assert EmailSuppressions.suppressed?("blocked@example.com")
      assert EmailSuppressions.suppressed?("complainer@example.com")
      assert EmailSuppressions.suppressed?("spam-notified@example.com")

      hard = Repo.get_by!(Plausible.EmailSuppression, email: "hard@example.com")
      assert hard.reason == :hard_bounce
      assert hard.source == :backfill
      assert hard.postmark_bounce_id == 1

      complainer = Repo.get_by!(Plausible.EmailSuppression, email: "complainer@example.com")
      assert complainer.reason == :spam_complaint
      assert complainer.source == :backfill

      spam_notified = Repo.get_by!(Plausible.EmailSuppression, email: "spam-notified@example.com")
      assert spam_notified.reason == :spam_notification
      assert spam_notified.source == :backfill
    end

    test "counts fetch failures separately" do
      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        case conn.query_params["type"] do
          "HardBounce" ->
            conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"Message" => "boom"})

          _other ->
            Req.Test.json(conn, %{"TotalCount" => 0, "Bounces" => []})
        end
      end)

      assert %{processed: 0, distinct_addresses: 0, upsert_errors: 0, fetch_errors: 1} =
               Postmark.backfill_suppressions()
    end

    test "counts distinct_addresses" do
      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        bounces =
          case conn.query_params["type"] do
            "HardBounce" ->
              [
                %{"Email" => "repeat@example.com", "ID" => 1},
                %{"Email" => "repeat@example.com", "ID" => 2}
              ]

            "Blocked" ->
              [%{"Email" => "repeat@example.com", "ID" => 3}]

            _other ->
              []
          end

        Req.Test.json(conn, %{"TotalCount" => length(bounces), "Bounces" => bounces})
      end)

      assert %{processed: 3, distinct_addresses: 1, upsert_errors: 0, fetch_errors: 0} =
               Postmark.backfill_suppressions()

      assert EmailSuppressions.suppressed?("repeat@example.com")
      assert Repo.aggregate(Plausible.EmailSuppression, :count) == 1
    end

    test "counts email citext variants" do
      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        bounces =
          case conn.query_params["type"] do
            "HardBounce" ->
              [%{"Email" => "Mixed.Case@Example.com", "ID" => 1}]

            "Blocked" ->
              [%{"Email" => "mixed.case@example.com", "ID" => 2}]

            _other ->
              []
          end

        Req.Test.json(conn, %{"TotalCount" => length(bounces), "Bounces" => bounces})
      end)

      assert %{processed: 2, distinct_addresses: 1, upsert_errors: 0, fetch_errors: 0} =
               Postmark.backfill_suppressions()

      assert Repo.aggregate(Plausible.EmailSuppression, :count) == 1
    end

    test "for multiple bounce events, the most recent one wins" do
      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        bounces =
          case conn.query_params["type"] do
            "HardBounce" ->
              [
                %{
                  "Email" => "flip@example.com",
                  "ID" => 1,
                  "BouncedAt" => "2026-01-01T00:00:00Z",
                  "Details" => "older hard bounce"
                }
              ]

            "Blocked" ->
              [
                %{
                  "Email" => "flip@example.com",
                  "ID" => 2,
                  "BouncedAt" => "2026-06-01T00:00:00Z",
                  "Details" => "newer block"
                }
              ]

            _other ->
              []
          end

        Req.Test.json(conn, %{"TotalCount" => length(bounces), "Bounces" => bounces})
      end)

      assert %{distinct_addresses: 1} = Postmark.backfill_suppressions()

      suppression = Repo.get_by!(Plausible.EmailSuppression, email: "flip@example.com")
      assert suppression.reason == :blocked
      assert suppression.postmark_bounce_id == 2
      assert suppression.details == "newer block"
    end

    test "spam complaint always wins over a bounce" do
      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        bounces =
          case conn.query_params["type"] do
            "HardBounce" ->
              [
                %{
                  "Email" => "complained@example.com",
                  "ID" => 1,
                  "BouncedAt" => "2026-06-01T00:00:00Z"
                }
              ]

            "SpamComplaint" ->
              [
                %{
                  "Email" => "complained@example.com",
                  "ID" => 2,
                  "BouncedAt" => "2026-01-01T00:00:00Z"
                }
              ]

            _other ->
              []
          end

        Req.Test.json(conn, %{"TotalCount" => length(bounces), "Bounces" => bounces})
      end)

      assert %{distinct_addresses: 1} = Postmark.backfill_suppressions()

      suppression = Repo.get_by!(Plausible.EmailSuppression, email: "complained@example.com")
      assert suppression.reason == :spam_complaint
      assert suppression.postmark_bounce_id == 2
    end

    test "the most recent spam complaint wins when there are several" do
      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        bounces =
          case conn.query_params["type"] do
            "SpamComplaint" ->
              [
                %{
                  "Email" => "repeat-complainer@example.com",
                  "ID" => 1,
                  "BouncedAt" => "2026-01-01T00:00:00Z"
                },
                %{
                  "Email" => "repeat-complainer@example.com",
                  "ID" => 2,
                  "BouncedAt" => "2026-06-01T00:00:00Z"
                }
              ]

            _other ->
              []
          end

        Req.Test.json(conn, %{"TotalCount" => length(bounces), "Bounces" => bounces})
      end)

      assert %{distinct_addresses: 1} = Postmark.backfill_suppressions()

      suppression =
        Repo.get_by!(Plausible.EmailSuppression, email: "repeat-complainer@example.com")

      assert suppression.postmark_bounce_id == 2
    end

    test "a missing BouncedAt does not crash the backfill" do
      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        bounces =
          case conn.query_params["type"] do
            "HardBounce" -> [%{"Email" => "no-timestamp@example.com", "ID" => 1}]
            _other -> []
          end

        Req.Test.json(conn, %{"TotalCount" => length(bounces), "Bounces" => bounces})
      end)

      assert %{distinct_addresses: 1, upsert_errors: 0} = Postmark.backfill_suppressions()
      assert EmailSuppressions.suppressed?("no-timestamp@example.com")
    end
  end
end
