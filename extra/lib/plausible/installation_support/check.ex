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
  @callback perform(state()) :: state()

  defmacro __using__(_) do
    quote do
      import Plausible.InstallationSupport.State
      alias Plausible.InstallationSupport.State

      require Logger

      @behaviour Plausible.InstallationSupport.Check

      def perform_safe(state, opts) do
        timeout = Keyword.get(opts, :timeout, 10_000)

        task =
          Task.async(fn ->
            try do
              perform(state)
            catch
              _, e ->
                Logger.error(
                  "Error running check #{inspect(__MODULE__)} on #{state.url}: #{inspect(e)}"
                )

                put_diagnostics(state, service_error: %{code: :internal_check_error, extra: e})
            end
          end)

        try do
          Task.await(task, timeout)
        catch
          :exit, {:timeout, _} ->
            Task.shutdown(task, :brutal_kill)
            check_name = __MODULE__ |> Atom.to_string() |> String.split(".") |> List.last()

            put_diagnostics(state,
              service_error: %{
                code: :internal_check_timeout,
                extra: "#{check_name} timed out after #{timeout}ms"
              }
            )
        end
      end
    end
  end
end
