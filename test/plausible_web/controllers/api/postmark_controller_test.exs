defmodule PlausibleWeb.Api.PostmarkControllerTest do
  use PlausibleWeb.ConnCase, async: true

  alias Plausible.EmailSuppressions

  # see config/.env.test
  @webhook_username "fake_webhook_username"
  @webhook_password "fake_webhook_password"

  setup %{conn: conn} do
    conn =
      Plug.Conn.put_req_header(
        conn,
        "authorization",
        Plug.BasicAuth.encode_basic_auth(@webhook_username, @webhook_password)
      )

    {:ok, conn: conn}
  end

  @bounce_payload %{
    "RecordType" => "Bounce",
    "ID" => 692_560_173,
    "Type" => "HardBounce",
    "TypeCode" => 1,
    "Email" => "bounced@example.com",
    "Details" => "Unknown user",
    "Inactive" => true,
    "CanActivate" => true
  }

  @spam_complaint_payload %{
    "RecordType" => "SpamComplaint",
    "ID" => 692_560_174,
    "Type" => "SpamComplaint",
    "TypeCode" => 100_001,
    "Email" => "complainer@example.com",
    "Details" => "Test spam complaint details",
    "Inactive" => true,
    "CanActivate" => false
  }

  describe "authentication" do
    test "rejects requests without valid basic auth", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header(
          "authorization",
          Plug.BasicAuth.encode_basic_auth("wrong", "creds")
        )
        |> post(~p"/api/postmark/webhook", @bounce_payload)

      assert conn.status == 401
      refute EmailSuppressions.suppressed?("bounced@example.com")
    end

    test "rejects requests with no authorization header at all", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.delete_req_header("authorization")
        |> post(~p"/api/postmark/webhook", @bounce_payload)

      assert conn.status == 401
    end
  end

  describe "Bounce webhook" do
    test "suppresses on a hard bounce", %{conn: conn} do
      conn = post(conn, ~p"/api/postmark/webhook", @bounce_payload)

      assert json_response(conn, 200) == %{}
      assert EmailSuppressions.suppressed?("bounced@example.com")
    end

    test "suppresses on a bad email address", %{conn: conn} do
      payload = %{@bounce_payload | "Type" => "BadEmailAddress"}
      conn = post(conn, ~p"/api/postmark/webhook", payload)

      assert json_response(conn, 200) == %{}
      assert EmailSuppressions.suppressed?("bounced@example.com")
    end

    test "suppresses on an ISP block", %{conn: conn} do
      payload = %{@bounce_payload | "Type" => "Blocked"}
      conn = post(conn, ~p"/api/postmark/webhook", payload)

      assert json_response(conn, 200) == %{}
      assert EmailSuppressions.suppressed?("bounced@example.com")
    end

    test "suppresses on a gateway spam-filter rejection (SpamNotification)", %{conn: conn} do
      payload = %{@bounce_payload | "Type" => "SpamNotification"}
      conn = post(conn, ~p"/api/postmark/webhook", payload)

      assert json_response(conn, 200) == %{}
      assert EmailSuppressions.suppressed?("bounced@example.com")

      suppression =
        Plausible.Repo.get_by!(Plausible.EmailSuppression, email: "bounced@example.com")

      assert suppression.reason == :spam_notification
    end

    test "ignores a transient/soft bounce", %{conn: conn} do
      payload = %{@bounce_payload | "Type" => "Transient"}
      conn = post(conn, ~p"/api/postmark/webhook", payload)

      assert json_response(conn, 200) == %{}
      refute EmailSuppressions.suppressed?("bounced@example.com")
    end

    test "records the Postmark bounce details", %{conn: conn} do
      post(conn, ~p"/api/postmark/webhook", @bounce_payload)

      suppression =
        Plausible.Repo.get_by!(Plausible.EmailSuppression, email: "bounced@example.com")

      assert suppression.reason == :hard_bounce
      assert suppression.source == :webhook
      assert suppression.postmark_bounce_id == 692_560_173
      assert suppression.postmark_inactive == true
      assert suppression.can_activate == true
      assert suppression.details == "Unknown user"
    end

    test "still acknowledges the webhook when the payload can't be persisted", %{conn: conn} do
      payload = Map.delete(@bounce_payload, "Email")
      conn = post(conn, ~p"/api/postmark/webhook", payload)

      assert json_response(conn, 200) == %{}
      assert Plausible.Repo.aggregate(Plausible.EmailSuppression, :count) == 0
    end
  end

  describe "SpamComplaint webhook" do
    test "suppresses the complaining address", %{conn: conn} do
      conn = post(conn, ~p"/api/postmark/webhook", @spam_complaint_payload)

      assert json_response(conn, 200) == %{}
      assert EmailSuppressions.suppressed?("complainer@example.com")

      suppression =
        Plausible.Repo.get_by!(Plausible.EmailSuppression, email: "complainer@example.com")

      assert suppression.reason == :spam_complaint
    end
  end

  describe "other webhook types" do
    setup %{test_pid: test_pid} do
      Plausible.Test.Support.Sentry.setup(test_pid)
    end

    test "acknowledges but ignores unhandled record types, reporting to Sentry", %{conn: conn} do
      conn =
        post(conn, ~p"/api/postmark/webhook", %{
          "RecordType" => "Delivery",
          "Email" => "delivered@example.com"
        })

      assert json_response(conn, 200) == %{}
      refute EmailSuppressions.suppressed?("delivered@example.com")

      assert [report] = Sentry.Test.pop_sentry_reports()
      assert report.message.formatted == "Received unexpected Postmark webhook record type"
      assert report.extra.record_type == "Delivery"
      assert report.extra.params["Email"] == "delivered@example.com"
    end
  end
end
