defmodule ObanErrorReporterTest do
  use ExUnit.Case, async: true

  describe "handle_event/4" do
    setup do
      :telemetry.attach_many(
        "oban-errors-test",
        [[:oban, :job, :exception], [:oban, :notifier, :exception], [:oban, :plugin, :exception]],
        &ObanErrorReporter.handle_event/4,
        %{}
      )

      on_exit(fn -> :ok = :telemetry.detach("oban-errors-test") end)
    end

    @tag :capture_log
    test "doesn't detach on failure" do
      :telemetry.execute([:oban, :job, :exception], %{}, %{job: %{}})

      handlers = :telemetry.list_handlers([:oban, :job, :exception])
      assert Enum.any?(handlers, &(&1.id == "oban-errors-test"))
    end

    test "logs an error on failure" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          :telemetry.execute([:oban, :job, :exception], %{}, %{job: %{}})
        end)

      assert log =~ "[error] ** (KeyError) key :reason not found in: %{job: %{}}"
    end
  end
end
