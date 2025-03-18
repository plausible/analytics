defmodule Plausible.Ingestion.Counters.BufferTest do
  use Plausible.DataCase, async: true
  alias Plausible.Ingestion.Counters.Buffer

  test "10s buckets are created from input datetime" do
    # time (...) :58 :59 :00 :01 :02 :03 :04 :05 :06 :07 :08 :09 :10 :11 :12 :13 (...)
    # bucket      50  50  00  00  00  00  00  00  00  00  00  00  10  10  10  10

    test_input = [
      %{input: ~N[2023-02-14 01:00:00], bucket: ~U[2023-02-14 01:00:00Z]},
      %{input: ~N[2023-02-14 01:00:02], bucket: ~U[2023-02-14 01:00:00Z]},
      %{input: ~N[2023-02-14 01:00:05], bucket: ~U[2023-02-14 01:00:00Z]},
      %{input: ~N[2023-02-14 01:00:09], bucket: ~U[2023-02-14 01:00:00Z]},
      %{input: ~N[2023-02-14 01:00:09.123456], bucket: ~U[2023-02-14 01:00:00Z]},
      %{input: ~N[2023-02-14 01:00:10], bucket: ~U[2023-02-14 01:00:10Z]},
      %{input: ~N[2023-02-14 01:00:59], bucket: ~U[2023-02-14 01:00:50Z]},
      %{input: ~N[2023-02-14 01:20:09], bucket: ~U[2023-02-14 01:20:00Z]}
    ]

    for t <- test_input do
      assert Buffer.bucket_10s(t.input) == DateTime.to_unix(t.bucket),
             "#{t.input} must fall into #{t.bucket} but got #{Buffer.bucket_10s(t.input) |> DateTime.from_unix!()}"
    end
  end

  test "aggregates metrics every 10 seconds", %{test: test} do
    # time (...) :58 :59 :00 :01 :02 :03 :04 :05 :06 :07 :08 :09 :10 :11 :12 :13 (...)
    # bucket      50  50  00  00  00  00  00  00  00  00  00  00  10  10  10  10
    # metric           x       x       x                       x
    # value            1       1       2                       3

    timestamps = [
      ~N[2023-02-14 01:00:59],
      ~N[2023-02-14 01:01:01],
      ~N[2023-02-14 01:01:03],
      ~N[2023-02-14 01:01:09]
    ]

    buffer = Buffer.new(test)

    for ts <- timestamps do
      Buffer.aggregate(buffer, "metric", "example.com", ts, 0)
    end

    assert [
             {bucket1, "metric", "example.com", 0, 1},
             {bucket2, "metric", "example.com", 0, 3}
           ] = Buffer.flush(buffer)

    assert bucket2 - bucket1 == 10
  end

  test "allows flushing only complete buckets", %{test: test} do
    # time (...) :58 :59 :00 :01 :02 :03 :04 :05 :06 :07 :08 :09 :10 :11 :12 :13 (...)
    # bucket      50  50  00  00  00  00  00  00  00  00  00  00  10  10  10  10
    # metric           x       x       x                       x
    # aggregate        1   0   1   1   2   2   2   2   2   2   3   3   0
    # flush attempt    x   x                   x                       x
    # flushed count    0   1                   0                       3

    timestamps = [
      ~N[2023-02-14 01:00:59],
      ~N[2023-02-14 01:01:01],
      ~N[2023-02-14 01:01:03],
      ~N[2023-02-14 01:01:09]
    ]

    buffer = Buffer.new(test)

    for ts <- timestamps do
      Buffer.aggregate(buffer, "metric", "example.com", ts, 0)
    end

    assert [] = Buffer.flush(buffer, ~U[2023-02-14 01:00:59.999999Z])
    assert [{_, _, _, 0, 1}] = Buffer.flush(buffer, ~U[2023-02-14 01:01:00.999999Z])
    assert [] = Buffer.flush(buffer, ~U[2023-02-14 01:01:05.999999Z])
    assert [{_, _, _, 0, 3}] = Buffer.flush(buffer, ~U[2023-02-14 01:01:11.999999Z])
  end

  test "allows setting tracker script version", %{test: test} do
    buffer = Buffer.new(test)

    Buffer.aggregate(buffer, "metric", "example.com", ~N[2023-02-14 01:00:59], 137)
    assert [{_, "metric", "example.com", 137, 1}] = Buffer.flush(buffer)
  end
end
