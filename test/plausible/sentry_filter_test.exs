defmodule Plausible.SentryFilterTest do
  use ExUnit.Case

  test "enforces fingerprint for ingestion request" do
    event =
      Sentry.Event.create_event(
        message: "oof",
        fingerprint: ["to be", " replaced"],
        extra: %{request: %Plausible.Ingestion.Request{}}
      )

    assert %Sentry.Event{fingerprint: ["ingestion_request"]} =
             Plausible.SentryFilter.before_send(event)
  end
end
