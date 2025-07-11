defmodule Plausible.InstallationSupport.CheckRunner do
  @moduledoc """
  Takes two arguments:

  1. A `%Plausible.InstallationSupport.State{}` struct - the `diagnostics`
     field is a struct representing the set of diagnostics shared between
     all the checks in this flow.

  2. A list of modules implementing `Plausible.InstallationSupport.Check`
     behaviour.

  Checks are normally run asynchronously, except when synchronous
  execution is optionally required for tests. Slowdowns can be optionally
  added, the user doesn't benefit from running the checks too quickly.
  """

  def run(state, checks, opts) do
    async? = Keyword.get(opts, :async?, true)
    slowdown = Keyword.get(opts, :slowdown, 500)

    if async? do
      Task.start_link(fn -> do_run(state, checks, slowdown) end)
    else
      do_run(state, checks, slowdown)
    end
  end

  defp do_run(state, checks, slowdown) do
    state =
      Enum.reduce(
        checks,
        state,
        fn check, state ->
          state
          |> notify_check_start(check, slowdown)
          |> check.perform_safe()
        end
      )

    notify_all_checks_done(state, slowdown)
  end

  defp notify_check_start(state, check, slowdown) do
    if is_pid(state.report_to) do
      if is_integer(slowdown) and slowdown > 0, do: :timer.sleep(slowdown)
      send(state.report_to, {:check_start, {check, state}})
    end

    state
  end

  defp notify_all_checks_done(state, slowdown) do
    if is_pid(state.report_to) do
      if is_integer(slowdown) and slowdown > 0, do: :timer.sleep(slowdown)
      send(state.report_to, {:all_checks_done, state})
    end

    state
  end
end
