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
      :ok =
        :telemetry.execute(
          [:oban, :job, :exception],
          _bad_measurements = %{},
          _bad_metadata = %{job: :bad_job}
        )

      handlers = :telemetry.list_handlers([:oban, :job, :exception])
      assert Enum.any?(handlers, &(&1.id == "oban-errors-test"))
    end

    test "logs an error on failure" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          :ok =
            :telemetry.execute(
              [:oban, :job, :exception],
              _bad_measurements = %{},
              _bad_metadata = %{job: :bad_job}
            )
        end)

      assert log =~ "[error] ** (BadMapError) expected a map, got: :bad_job"
    end
  end
end
