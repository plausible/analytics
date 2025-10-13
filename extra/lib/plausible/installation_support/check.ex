defmodule Plausible.InstallationSupport.Check do
  @moduledoc """
  Behaviour to be implemented by a specific installation support check.

  `report_progress_as()` doesn't necessarily reflect the actual check
  description, it serves as a user-facing message grouping mechanism,
  to prevent frequent message flashing when checks rotate often.

  Each check operates on `%Plausible.InstallationSupport.State{}` and is
  expected to return it, optionally modified, by all means. `perform_safe/1`
  is used to guarantee no exceptions are thrown by faulty implementations,
  not to interrupt LiveView.
  """
  @type state() :: Plausible.InstallationSupport.State.t()
  @callback report_progress_as() :: String.t()
  @callback timeout_ms() :: integer()
  @callback perform(state()) :: state()

  defmacro __using__(_) do
    quote do
      import Plausible.InstallationSupport.State
      alias Plausible.InstallationSupport.State

      require Logger

      @behaviour Plausible.InstallationSupport.Check

      def timeout_ms, do: 10_000

      defoverridable timeout_ms: 0

      def perform_safe(state) do
        task =
          Task.async(fn ->
            try do
              perform(state)
            catch
              _, e ->
                Logger.error(
                  "Error running check #{inspect(__MODULE__)} on #{state.url}: #{inspect(e)}"
                )

                put_diagnostics(state, service_error: e)
            end
          end)

        Task.await(task, timeout_ms())
      catch
        _ -> put_diagnostics(state, service_error: :check_timeout)
      end
    end
  end
end
