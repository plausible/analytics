defmodule Plausible.Ingestion.Counters.BufferTest do
  use Plausible.DataCase, async: true
  alias Plausible.Ingestion.Counters.Buffer

  test "aggregates metrics every minute", %{test: test} do
    aggregates =
      test
      |> Buffer.new()
      |> Buffer.aggregate("metric1", "example.com", ~U[2023-02-14 01:00:18.123456Z])
      |> Buffer.aggregate("metric1", "example.com", ~U[2023-02-14 01:00:28.123456Z])
      |> Buffer.aggregate("metric2", "example.com", ~U[2023-02-14 01:00:28.123456Z])
      |> Buffer.aggregate("metric1", "example.com", ~U[2023-02-14 01:00:59.123456Z])
      |> Buffer.aggregate("metric1", "example.com", ~U[2023-02-14 01:01:00.123456Z])
      |> Buffer.aggregate("metric2", "example.com", ~U[2023-02-14 01:02:00.123456Z])
      |> Buffer.flush()

    assert [
             {bucket1, "metric1", "example.com", 3},
             {bucket1, "metric2", "example.com", 1},
             {bucket2, "metric1", "example.com", 1},
             {bucket3, "metric2", "example.com", 1}
           ] = aggregates

    assert bucket3 - bucket2 == 60
    assert bucket2 - bucket1 == 60
  end

  test "does not flush current bucket until its time passes", %{test: test} do
    now = ~U[2023-02-14 01:01:00.123456Z]

    buffer = Buffer.new(test)

    assert [{_, "metric1", "example.com", 1}] =
             buffer
             |> Buffer.aggregate("metric1", "example.com", ~U[2023-02-14 01:00:00.123456Z])
             |> Buffer.aggregate("metric2", "another.example.com", now)
             |> Buffer.flush(now)

    assert [{_, "metric2", "another.example.com", 1}] = Buffer.flush(buffer)
  end
end
