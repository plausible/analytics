defmodule Plausible.Test.Support.Sentry do
  @moduledoc """
  Helper for setting up Sentry test mode in ExUnit tests.

  Usage inside a `setup` callback:

      setup %{test_pid: test_pid} do
        Plausible.Test.Support.Sentry.setup(test_pid)
      end

  This enables Sentry's test mode, starts collecting reports owned by the
  test process, and restores the original config on exit.
  """

  def setup(test_pid) do
    Sentry.put_config(:test_mode, true)
    Sentry.put_config(:send_result, :sync)
    Sentry.put_config(:dedup_events, false)

    :ok = Sentry.Test.start_collecting(owner: test_pid)

    ExUnit.Callbacks.on_exit(fn ->
      Sentry.put_config(:test_mode, false)
      Sentry.put_config(:send_result, :none)
      Sentry.put_config(:dedup_events, true)
    end)
  end
end
