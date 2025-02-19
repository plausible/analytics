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

  test "ignores excess cowboy error messages" do
    event = %Sentry.Event{
      event_id: "5f0a9f9b04df4050884966c87a4e62b8",
      timestamp: "2025-02-19T13:23:05.705493",
      extra: %{logger_level: :error, logger_metadata: %{}},
      level: :error,
      logger: nil,
      message: %Sentry.Interfaces.Message{
        message: nil,
        params: nil,
        formatted:
          "Ranch listener PlausibleWeb.Endpoint.HTTP, connection process #PID<0.1216.0>, " <>
            "stream 1 had its request process #PID<0.1217.0> exit with " <>
            "reason {{{%Plug.Parsers.ParseError{\n ..."
      },
      source: :logger
    }

    assert Plausible.SentryFilter.before_send(event) == false
  end
end
