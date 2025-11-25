defmodule Plausible.Ingestion.PersistorSyncTest do
  use Plausible.DataCase, async: false

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

  setup do
    on_exit(fn ->
      Application.put_env(:plausible, Persistor,
        backend_percent_enabled: 0,
        backend: Persistor.Embedded
      )
    end)
  end

  describe "backend_percent_enabled" do
    test "ingests with embedded persistor when backend set to 100% and left on default" do
      Application.put_env(:plausible, Persistor,
        backend_percent_enabled: 100,
        backend: Persistor.Embedded
      )

      event = build(:event, name: "pageview")
      ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

      assert {:ok, ingested_event} = Persistor.persist_event(ingest_event, nil, [])
      refute ingested_event.dropped?
      assert ingested_event.clickhouse_event.operating_system == "Mac"
      assert is_integer(ingested_event.clickhouse_event.session_id)
    end

    test "ingests with embedded persistor when backend set to < 100%" do
      Application.put_env(:plausible, Persistor,
        backend_percent_enabled: 10,
        backend: Persistor.Embedded
      )

      event = build(:event, name: "pageview")
      ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

      assert {:ok, ingested_event} = Persistor.persist_event(ingest_event, nil, [])
      refute ingested_event.dropped?
      assert ingested_event.clickhouse_event.operating_system == "Mac"
      assert is_integer(ingested_event.clickhouse_event.session_id)
    end

    test "ingests with remote persistor for a fraction of users with fallback to embedded when set to < 100%" do
      Application.put_env(:plausible, Persistor,
        backend_percent_enabled: 50,
        backend: Persistor.Remote
      )

      bypass = Bypass.open()

      Application.put_env(:plausible, Persistor.Remote, url: bypass_url(bypass))

      current_pid = self()

      expect_persistor(bypass, fn input_event, session_attrs ->
        send(current_pid, :remote_ingest)

        input_event
        |> Map.merge(session_attrs)
        |> Map.put(:session_id, System.unique_integer())
      end)

      assert ingest_via_both_backends(false, false, 10) == :ok
    end

    defp ingest_via_both_backends(true, true, _), do: :ok

    defp ingest_via_both_backends(_, _, 0), do: :out_of_attempts

    defp ingest_via_both_backends(embedded_ingested?, remote_ingested?, attempts_left) do
      event = build(:event, name: "pageview")
      ingest_event = %Event{clickhouse_event: event, clickhouse_session_attrs: @session_params}

      current_pid = self()

      assert {:ok, _ingested_event} =
               Persistor.persist_event(ingest_event, nil,
                 session_write_buffer_insert: fn [session] = sessions ->
                   assert session.user_id == event.user_id
                   assert session.site_id == event.site_id
                   send(current_pid, :embedded_ingest)
                   {:ok, sessions}
                 end
               )

      receive do
        :embedded_ingest ->
          ingest_via_both_backends(true, remote_ingested?, attempts_left - 1)

        :remote_ingest ->
          ingest_via_both_backends(embedded_ingested?, true, attempts_left - 1)
      after
        100 ->
          :ingest_not_called
      end
    end

    defp bypass_url(bypass) do
      "http://localhost:#{bypass.port}/event"
    end

    defp expect_persistor(bypass, callback_fn) do
      Bypass.expect(bypass, "POST", "/event", fn conn ->
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
end
