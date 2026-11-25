defmodule Plausible.PostmarkTest do
  use Plausible.DataCase, async: true
  @moduletag :ee_only
  @moduletag :capture_log

  alias Plausible.Postmark

  @streams ["outbound", "priority", "untrusted-recipients"]
  @delete_paths Enum.map(@streams, &"/message-streams/#{&1}/suppressions/delete")

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

  describe "delete_suppression/1" do
    test "deletes the suppression from every stream we send from" do
      Req.Test.stub(Postmark, fn conn ->
        assert conn.method == "POST"

        assert conn.request_path in @delete_paths

        conn = Plug.Conn.fetch_query_params(conn)
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"Suppressions" => [%{"EmailAddress" => "a@example.com"}]}

        Req.Test.json(conn, %{
          "Suppressions" => [%{"EmailAddress" => "a@example.com", "Status" => "Deleted"}]
        })
      end)

      assert :ok = Postmark.delete_suppression("a@example.com")
    end

    test "no-ops (still :ok) when the address wasn't suppressed on a stream" do
      Req.Test.stub(Postmark, fn conn ->
        Req.Test.json(conn, %{
          "Suppressions" => [
            %{"EmailAddress" => "a@example.com", "Status" => "Deleted", "Message" => nil}
          ]
        })
      end)

      assert :ok = Postmark.delete_suppression("a@example.com")
    end

    test "returns an error when Postmark refuses (e.g. a spam complaint can't be deleted)" do
      Req.Test.stub(Postmark, fn conn ->
        Req.Test.json(conn, %{
          "Suppressions" => [
            %{
              "EmailAddress" => "a@example.com",
              "Status" => "Failed",
              "Message" => "SpamComplaint suppressions cannot be deleted"
            }
          ]
        })
      end)

      assert {:error, {stream, "SpamComplaint suppressions cannot be deleted"}} =
               Postmark.delete_suppression("a@example.com")

      assert stream in @streams
    end

    test "returns an error on a non-200 response from any stream" do
      Req.Test.stub(Postmark, fn conn ->
        case conn.request_path do
          "/message-streams/priority/suppressions/delete" ->
            conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"Message" => "boom"})

          _other_stream ->
            Req.Test.json(conn, %{
              "Suppressions" => [%{"EmailAddress" => "a@example.com", "Status" => "Deleted"}]
            })
        end
      end)

      assert {:error, {:unexpected_status, 500, _body}} =
               Postmark.delete_suppression("a@example.com")
    end
  end

  describe "delete_suppressions/1" do
    test "no-ops without making any request for an empty list" do
      Req.Test.stub(Postmark, fn _conn -> flunk("Postmark should not have been called") end)

      assert [] = Postmark.delete_suppressions([])
    end

    test "deletes every address, on every stream, in a single request each, and confirms all" do
      test_pid = self()

      Req.Test.stub(Postmark, fn conn ->
        assert conn.request_path in @delete_paths

        conn = Plug.Conn.fetch_query_params(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:request, conn.request_path, Jason.decode!(body)})

        Req.Test.json(conn, %{
          "Suppressions" => [
            %{"EmailAddress" => "a@example.com", "Status" => "Deleted"},
            %{"EmailAddress" => "b@example.com", "Status" => "Deleted"}
          ]
        })
      end)

      assert Postmark.delete_suppressions(["a@example.com", "b@example.com"]) == [
               "a@example.com",
               "b@example.com"
             ]

      for stream <- @streams do
        path = "/message-streams/#{stream}/suppressions/delete"
        assert_received {:request, ^path, body}

        assert body == %{
                 "Suppressions" => [
                   %{"EmailAddress" => "a@example.com"},
                   %{"EmailAddress" => "b@example.com"}
                 ]
               }
      end
    end

    test "splits a large batch into multiple requests per stream, respecting Postmark's max of 50" do
      test_pid = self()
      emails = for n <- 1..51, do: "user-#{n}@example.com"

      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        %{"Suppressions" => suppressions} = Jason.decode!(body)
        send(test_pid, {:chunk_size, length(suppressions)})

        Req.Test.json(
          conn,
          %{"Suppressions" => Enum.map(suppressions, &Map.put(&1, "Status", "Deleted"))}
        )
      end)

      assert Postmark.delete_suppressions(emails) |> length() == 51

      # 51 emails, chunked at 50, on each stream = 2 requests per stream
      for _stream <- @streams do
        assert_received {:chunk_size, 50}
        assert_received {:chunk_size, 1}
      end
    end

    test "still confirms addresses Postmark refused (e.g. a spam complaint), only logging it" do
      Req.Test.stub(Postmark, fn conn ->
        Req.Test.json(conn, %{
          "Suppressions" => [
            %{"EmailAddress" => "a@example.com", "Status" => "Deleted"},
            %{
              "EmailAddress" => "complainer@example.com",
              "Status" => "Failed",
              "Message" => "SpamComplaint suppressions cannot be deleted"
            }
          ]
        })
      end)

      assert Postmark.delete_suppressions(["a@example.com", "complainer@example.com"]) == [
               "a@example.com",
               "complainer@example.com"
             ]
    end

    test "does not confirm a chunk whose call errored outright on any stream" do
      Req.Test.stub(Postmark, fn conn ->
        case conn.request_path do
          "/message-streams/priority/suppressions/delete" ->
            conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"Message" => "boom"})

          _other_stream ->
            Req.Test.json(conn, %{
              "Suppressions" => [%{"EmailAddress" => "a@example.com", "Status" => "Deleted"}]
            })
        end
      end)

      assert Postmark.delete_suppressions(["a@example.com"]) == []
    end

    test "only leaves out the chunk that failed, not unrelated chunks" do
      ok_emails = for n <- 1..50, do: "ok-#{n}@example.com"
      failing_email = "unreachable@example.com"

      Req.Test.stub(Postmark, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        %{"Suppressions" => suppressions} = Jason.decode!(body)

        if Enum.any?(suppressions, &(&1["EmailAddress"] == failing_email)) do
          conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"Message" => "boom"})
        else
          Req.Test.json(
            conn,
            %{"Suppressions" => Enum.map(suppressions, &Map.put(&1, "Status", "Deleted"))}
          )
        end
      end)

      confirmed = Postmark.delete_suppressions(ok_emails ++ [failing_email])

      assert Enum.sort(confirmed) == Enum.sort(ok_emails)
      refute failing_email in confirmed
    end
  end
end
