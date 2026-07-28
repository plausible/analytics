defmodule Plausible.InstallationSupport.CheckRunnerTest do
  use Plausible.DataCase, async: true

  on_ee do
    alias Plausible.InstallationSupport.{CheckRunner, State}

    defmodule NoopCheck do
      @moduledoc false
      use Plausible.InstallationSupport.Check

      @impl true
      def report_progress_as, do: "noop"

      @impl true
      def perform(state, _opts), do: state
    end

    defp init_state do
      %State{url: "https://example.com", data_domain: "example.com", report_to: self()}
    end

    describe "run/3" do
      test "defaults launch_delay to 0" do
        started_at = System.monotonic_time(:millisecond)

        CheckRunner.run(init_state(), [{NoopCheck, []}], async?: false, slowdown: 0)

        assert System.monotonic_time(:millisecond) - started_at < 100
      end

      test "awaits :launch_delay before the first check starts" do
        started_at = System.monotonic_time(:millisecond)

        {:ok, _pid} =
          CheckRunner.run(init_state(), [{NoopCheck, []}],
            slowdown: 0,
            launch_delay: 100,
            report_to: self()
          )

        assert_receive {:check_start, {NoopCheck, _state}}, 1000

        assert System.monotonic_time(:millisecond) - started_at >= 100
      end

      test "runs the first check immediately when :launch_delay is 0" do
        {:ok, _pid} =
          CheckRunner.run(init_state(), [{NoopCheck, []}],
            slowdown: 0,
            launch_delay: 0,
            report_to: self()
          )

        assert_receive {:check_start, {NoopCheck, _state}}, 100
      end
    end
  end
end
