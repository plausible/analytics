defmodule Plausible.Workers.CleanEmailSuppressionsTest do
  use Plausible.DataCase
  @moduletag :ee_only
  @moduletag :capture_log

  import ExUnit.CaptureLog

  alias Plausible.EmailSuppressions
  alias Plausible.Postmark
  alias Plausible.Workers.CleanEmailSuppressions

  defp create_stale_suppression(email, opts \\ []) do
    source = Keyword.get(opts, :source, :backfill)

    {:ok, suppression} =
      EmailSuppressions.create_from_bounce(%{email: email, reason: :hard_bounce, source: source})

    suppression
    |> Ecto.Changeset.change(
      updated_at: NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: -15)
    )
    |> Repo.update!()
  end

  test "removes a stale suppression with no matching user, invitation or transfer" do
    create_stale_suppression("orphaned@example.com")

    Req.Test.stub(Postmark, fn conn ->
      Req.Test.json(conn, %{
        "Suppressions" => [%{"EmailAddress" => "orphaned@example.com", "Status" => "Deleted"}]
      })
    end)

    assert :ok = CleanEmailSuppressions.perform(nil)

    refute Repo.exists?(Plausible.EmailSuppression)
  end

  test "keeps a stale suppression that still matches a user, regardless of Postmark" do
    insert(:user, email: "still-a-user@example.com")
    create_stale_suppression("still-a-user@example.com")

    Req.Test.stub(Postmark, fn _conn -> flunk("Postmark should not have been called") end)

    assert :ok = CleanEmailSuppressions.perform(nil)

    assert Repo.exists?(Plausible.EmailSuppression)
  end

  test "keeps a suppression that isn't stale enough yet" do
    {:ok, _suppression} =
      EmailSuppressions.create_from_bounce(%{
        email: "fresh@example.com",
        reason: :hard_bounce,
        source: :backfill
      })

    Req.Test.stub(Postmark, fn _conn -> flunk("Postmark should not have been called") end)

    assert :ok = CleanEmailSuppressions.perform(nil)

    assert Repo.exists?(Plausible.EmailSuppression)
  end

  test "still removes the local row when Postmark refuses (e.g. a spam complaint)" do
    {:ok, suppression} =
      EmailSuppressions.create_from_spam_complaint(%{
        email: "complainer@example.com",
        source: :backfill
      })

    suppression
    |> Ecto.Changeset.change(
      updated_at: NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: -15)
    )
    |> Repo.update!()

    Req.Test.stub(Postmark, fn conn ->
      Req.Test.json(conn, %{
        "Suppressions" => [
          %{
            "EmailAddress" => "complainer@example.com",
            "Status" => "Failed",
            "Message" => "SpamComplaint suppressions cannot be deleted"
          }
        ]
      })
    end)

    log = capture_log(fn -> assert :ok = CleanEmailSuppressions.perform(nil) end)

    assert log =~ "Failed to delete some Postmark suppressions"
    assert log =~ "complainer@example.com"
    assert log =~ "SpamComplaint suppressions cannot be deleted"

    refute Repo.exists?(Plausible.EmailSuppression)
  end

  test "keeps the local row when Postmark call errors out (to retry later)" do
    create_stale_suppression("good@example.com")
    create_stale_suppression("unreachable@example.com")

    Req.Test.stub(Postmark, fn conn ->
      conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"Message" => "boom"})
    end)

    log = capture_log(fn -> assert :ok = CleanEmailSuppressions.perform(nil) end)

    assert log =~ "Failed to delete a batch of 2 Postmark suppressions"
    assert log =~ "unexpected_status, 500"

    assert Repo.exists?(Plausible.EmailSuppression)
  end

  test "removes every row in a chunk whose call succeeded, even one Postmark refused" do
    create_stale_suppression("deleted-fine@example.com")

    {:ok, complaint} =
      EmailSuppressions.create_from_spam_complaint(%{
        email: "complainer@example.com",
        source: :backfill
      })

    complaint
    |> Ecto.Changeset.change(
      updated_at: NaiveDateTime.utc_now(:second) |> NaiveDateTime.shift(day: -15)
    )
    |> Repo.update!()

    Req.Test.stub(Postmark, fn conn ->
      Req.Test.json(conn, %{
        "Suppressions" => [
          %{"EmailAddress" => "deleted-fine@example.com", "Status" => "Deleted"},
          %{
            "EmailAddress" => "complainer@example.com",
            "Status" => "Failed",
            "Message" => "SpamComplaint suppressions cannot be deleted"
          }
        ]
      })
    end)

    log = capture_log(fn -> assert :ok = CleanEmailSuppressions.perform(nil) end)

    assert log =~ "Failed to delete some Postmark suppressions"
    assert log =~ "complainer@example.com"

    # The HTTP call itself completed, so the whole chunk is confirmed,
    # even if Postmark refused to delete some suppressions
    refute Repo.exists?(Plausible.EmailSuppression)
  end

  test "removes only the chunk Postmark confirmed, keeping the rest for next time" do
    for n <- 1..50 do
      create_stale_suppression("confirmed-#{n}@example.com")
    end

    create_stale_suppression("unreachable@example.com")

    Req.Test.stub(Postmark, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      %{"Suppressions" => suppressions} = Jason.decode!(body)

      if Enum.any?(suppressions, &(&1["EmailAddress"] == "unreachable@example.com")) do
        conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"Message" => "boom"})
      else
        Req.Test.json(
          conn,
          %{"Suppressions" => Enum.map(suppressions, &Map.put(&1, "Status", "Deleted"))}
        )
      end
    end)

    log = capture_log(fn -> assert :ok = CleanEmailSuppressions.perform(nil) end)

    assert log =~ "Failed to delete a batch of 1 Postmark suppressions"
    assert log =~ "unexpected_status, 500"

    refute Repo.get_by(Plausible.EmailSuppression, email: "confirmed-1@example.com")
    assert Repo.get_by(Plausible.EmailSuppression, email: "unreachable@example.com")
  end

  test "does nothing when there are no candidates" do
    Req.Test.stub(Postmark, fn _conn -> flunk("Postmark should not have been called") end)

    assert :ok = CleanEmailSuppressions.perform(nil)
  end
end
