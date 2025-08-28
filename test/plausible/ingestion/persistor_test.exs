defmodule Plausible.Ingestion.PersistorTest do
  use Plausible.DataCase

  import ExUnit.CaptureLog

  alias Plausible.Ingestion.Event
  alias Plausible.Ingestion.Persistor

  @session_params %{
    referrer: "ref",
    referrer_source: "refsource",
    utm_medium: "medium",
    utm_source: "source",
    utm_campaign: "campaign",
    utm_content: "content",
    utm_term: "term",
    browser: "browser",
    browser_version: "55",
    country_code: "EE",
    screen_size: "Desktop",
    operating_system: "Mac",
    operating_system_version: "11"
  }

  test "ingests using default, embedded persistor" do
    event = build(:event, name: "pageview")
    ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

    assert {:ok, ingested_event} = Persistor.persist_event(ingest_event, nil, [])
    refute ingested_event.dropped?
    assert ingested_event.clickhouse_event.operating_system == "Mac"
    assert is_integer(ingested_event.clickhouse_event.session_id)
  end

  test "ingests using remote persistor" do
    event = build(:event, name: "pageview")
    ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

    bypass = Bypass.open()

    expect_persistor(bypass, fn input_event, session_attrs ->
      assert session_attrs == @session_params
      assert input_event.user_id == event.user_id

      input_event
      |> Map.merge(session_attrs)
      |> Map.put(:session_id, 123)
    end)

    assert {:ok, ingested_event} =
             Persistor.persist_event(ingest_event, nil,
               backend: Persistor.Remote,
               url: bypass_url(bypass)
             )

    refute ingested_event.dropped?
    assert ingested_event.clickhouse_event.session_id == 123
  end

  test "ingests using persistor with relay" do
    conn =
      Phoenix.ConnTest.build_conn(:post, "/api/events", %{
        name: "pageview",
        url: "http://dummy.site"
      })

    {:ok, request} = Plausible.Ingestion.Request.build(conn)

    event = build(:event, name: "pageview")

    ingest_event = %Event{
      clickhouse_event: event,
      clickhouse_session_attrs: @session_params,
      request: request
    }

    bypass = Bypass.open()

    expect_persistor(bypass, fn input_event, session_attrs ->
      assert session_attrs == @session_params
      assert input_event.user_id == event.user_id

      input_event
      |> Map.merge(session_attrs)
      |> Map.put(:session_id, 123)
    end)

    assert {:ok, ingested_event} =
             Persistor.persist_event(ingest_event, nil,
               backend: Persistor.EmbeddedWithRelay,
               url: bypass_url(bypass),
               sync?: true
             )

    refute ingested_event.dropped?
    assert is_integer(ingested_event.clickhouse_event.session_id)
    assert ingested_event.clickhouse_event.session_id != 123
  end

  test "remote persistor failing due to invalid response payload" do
    event = build(:event, name: "pageview")
    ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/event", fn conn ->
      event_payload = Base.encode64("invalid", padding: false)

      conn
      |> Plug.Conn.resp(200, event_payload)
    end)

    assert capture_log(fn ->
             assert {:error, :persist_decode_error} =
                      Persistor.persist_event(ingest_event, nil,
                        backend: Persistor.Remote,
                        url: bypass_url(bypass)
                      )
           end) =~ "invalid_payload"
  end

  test "remote persistor failing due to invalid response payload encoding" do
    event = build(:event, name: "pageview")
    ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/event", fn conn ->
      conn
      |> Plug.Conn.resp(200, "invalid encoding")
    end)

    assert capture_log(fn ->
             assert {:error, :persist_decode_error} =
                      Persistor.persist_event(ingest_event, nil,
                        backend: Persistor.Remote,
                        url: bypass_url(bypass)
                      )
           end) =~ "invalid_web_encoding"
  end

  test "remote persistor failing due to no session for engagement" do
    event = build(:event, name: "pageview")
    ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/event", fn conn ->
      conn
      |> Plug.Conn.resp(500, "no_session_for_engagement")
    end)

    assert capture_log(fn ->
             assert {:error, :no_session_for_engagement} =
                      Persistor.persist_event(ingest_event, nil,
                        backend: Persistor.Remote,
                        url: bypass_url(bypass)
                      )
           end) =~ "no_session_for_engagement"
  end

  test "remote persistor failing due to lock timeout" do
    event = build(:event, name: "pageview")
    ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/event", fn conn ->
      conn
      |> Plug.Conn.resp(500, "lock_timeout")
    end)

    assert capture_log(fn ->
             assert {:error, :lock_timeout} =
                      Persistor.persist_event(ingest_event, nil,
                        backend: Persistor.Remote,
                        url: bypass_url(bypass)
                      )
           end) =~ "lock_timeout"
  end

  test "remote persistor failing due to unknown server error" do
    event = build(:event, name: "pageview")
    ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/event", fn conn ->
      conn
      |> Plug.Conn.resp(500, "unknown_error")
    end)

    assert capture_log(fn ->
             assert {:error, :persist_error} =
                      Persistor.persist_event(ingest_event, nil,
                        backend: Persistor.Remote,
                        url: bypass_url(bypass)
                      )
           end) =~ "unknown_error"
  end

  test "remote persistor failing due to network error" do
    event = build(:event, name: "pageview")
    ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

    bypass = Bypass.open()
    Bypass.down(bypass)

    assert capture_log(fn ->
             assert {:error, :persist_error} =
                      Persistor.persist_event(ingest_event, nil,
                        backend: Persistor.Remote,
                        url: bypass_url(bypass)
                      )
           end) =~ "econnrefused"
  end

  defp bypass_url(bypass) do
    "http://localhost:#{bypass.port}/event"
  end

  defp expect_persistor(bypass, callback_fn) do
    Bypass.expect_once(bypass, "POST", "/event", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      {input_event, session_attrs} =
        body
        |> Base.decode64!(padding: false)
        |> :erlang.binary_to_term()

      output_event = callback_fn.(input_event, session_attrs)

      event_payload =
        output_event
        |> Map.merge(session_attrs)
        |> Map.put(:session_id, 123)
        |> :erlang.term_to_binary()
        |> Base.encode64(padding: false)

      conn
      |> Plug.Conn.resp(200, event_payload)
    end)
  end
end
