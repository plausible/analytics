defmodule Plausible.Verification.Check do
  @moduledoc """
  Behaviour to be implemented by specific site verification checks.
  `report_progress_as()` doesn't necessarily reflect the actual check description,
  it serves as a user-facing message grouping mechanism, to prevent frequent message flashing when checks rotate often.
  Each check operates on `state()` and is expected to return it, optionally modified, by all means.
  `perform_safe/1` is used to guarantee no exceptions are thrown by faulty implementations, not to interrupt LiveView.
  """
  @type state() :: Plausible.Verification.State.t()
  @callback report_progress_as() :: String.t()
  @callback perform(state()) :: state()

  defmacro __using__(_) do
    quote do
      import Plausible.Verification.State

      alias Plausible.Verification.Checks
      alias Plausible.Verification.State
      alias Plausible.Verification.Diagnostics

      require Logger

      @behaviour Plausible.Verification.Check

      def perform_safe(state) do
        perform(state)
      catch
        _, e ->
          Logger.error(
            "Error running check #{inspect(__MODULE__)} on #{state.url}: #{inspect(e)}"
          )

          put_diagnostics(state, service_error: e)
      end
    end
  end
end
