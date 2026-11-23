defmodule PlausibleWeb.Api.PaddleBillingControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo
  use Plausible.Teams.Test

  import ExUnit.CaptureLog
  import Plausible.Billing.PaddleBilling.WebhookFixtures

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.PaddleBilling.SubscriptionEvent
  alias Plausible.Billing.Subscription.Status
  alias Plausible.Teams

  @moduletag :ee_only

  setup do
    {:ok, team} = Teams.get_or_create(new_user())
    {:ok, team: team}
  end

  defp created_event(team, data \\ %{}) do
    subscription_event("subscription.created",
      data: Map.put(data, :custom_data, %{"team_id" => team.id})
    )
  end

  describe "authentication" do
    test "accepts a correctly signed event", %{conn: conn, team: team} do
      conn = post_signed(conn, created_event(team))

      assert response(conn, 200)
      assert %{type: :billing} = Teams.with_subscription(team).subscription
    end

    test "verifies the signature over the raw body, not the parsed one", %{conn: conn, team: team} do
      conn = post_signed(conn, created_event(team), pretty: true)

      assert response(conn, 200)
      assert %{type: :billing} = Teams.with_subscription(team).subscription
    end

    test "rejects an event without the signature header", %{conn: conn, team: team} do
      log =
        capture_log(fn ->
          assert conn |> post_signed(created_event(team), signature_header: nil) |> response(400)
        end)

      assert log =~ "Rejected Paddle Billing webhook: malformed_header"
      refute Teams.with_subscription(team).subscription
    end

    test "rejects an event signed with another secret", %{conn: conn, team: team} do
      log =
        capture_log(fn ->
          assert conn
                 |> post_signed(created_event(team), secret: "pdl_ntfset_someone_else")
                 |> response(400)
        end)

      assert log =~ "Rejected Paddle Billing webhook: invalid_signature"
      refute Teams.with_subscription(team).subscription
    end

    test "rejects an event whose body was changed after signing", %{conn: conn, team: team} do
      event = created_event(team)
      tampered = Jason.encode!(put_in(event, ["data", "status"], "paused"))

      log =
        capture_log(fn ->
          assert conn |> post_signed(event, send_body: tampered) |> response(400)
        end)

      assert log =~ "Rejected Paddle Billing webhook: invalid_signature"
      refute Teams.with_subscription(team).subscription
    end

    test "rejects a replayed event with an old timestamp", %{conn: conn, team: team} do
      log =
        capture_log(fn ->
          assert conn
                 |> post_signed(created_event(team), ts: System.system_time(:second) - 60)
                 |> response(400)
        end)

      assert log =~ "Rejected Paddle Billing webhook: stale_timestamp"
      refute Teams.with_subscription(team).subscription
    end

    test "rejects everything when the secret is not configured", %{conn: conn, team: team} do
      patch_env(:paddle_billing, webhook_secret: nil)

      log =
        capture_log(fn ->
          assert conn |> post_signed(created_event(team), secret: "anything") |> response(400)
        end)

      assert log =~ "Rejected Paddle Billing webhook: missing_secret"
      refute Teams.with_subscription(team).subscription
    end
  end

  describe "processing" do
    test "stores the subscription once, however many times the event is delivered", %{
      conn: conn,
      team: team
    } do
      event = created_event(team)

      assert conn |> post_signed(event) |> response(200)
      assert build_conn() |> post_signed(event) |> response(200)

      assert %{type: :billing} = Teams.with_subscription(team).subscription
      assert Repo.aggregate(SubscriptionEvent, :count) == 1
    end

    test "applies subscription.updated", %{conn: conn, team: team} do
      assert conn |> post_signed(created_event(team)) |> response(200)

      updated =
        subscription_event("subscription.updated",
          occurred_at: "2026-11-11T10:00:00.000000Z",
          data: %{status: "past_due"}
        )

      assert build_conn() |> post_signed(updated) |> response(200)

      assert Teams.with_subscription(team).subscription.status == Status.past_due()
    end

    test "acknowledges events that are not handled", %{conn: conn, team: team} do
      event = subscription_event("subscription.past_due")

      assert conn |> post_signed(event) |> response(200)
      refute Teams.with_subscription(team).subscription
      refute Repo.exists?(SubscriptionEvent)
    end

    test "responds with an error when the event can't be processed, so Paddle retries", %{
      conn: conn
    } do
      no_custom_data = subscription_event("subscription.created")
      unknown = subscription_event("subscription.updated", data: %{id: "sub_unknown"})

      log =
        capture_log(fn ->
          assert conn |> post_signed(no_custom_data) |> response(400)
          assert build_conn() |> post_signed(unknown) |> response(400)
        end)

      assert log =~ "Error processing Paddle Billing webhook: :invalid_custom_data"
      assert log =~ "Error processing Paddle Billing webhook: :subscription_not_found"
    end
  end
end
