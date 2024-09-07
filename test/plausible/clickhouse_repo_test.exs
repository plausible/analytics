defmodule Plausible.ClickhouseRepoTest do
  use ExUnit.Case, async: false
  use Plausible.TestUtils
  alias Plausible.ClickhouseRepo

  describe "parallel_tasks/2" do
    @tag :slow
    @tag :capture_log
    @tag :ce_build_only
    test "has configurable timeout in CE" do
      # timeout is now 100ms, meaning:
      # - ch times out after 100ms
      # - tasks time out after 400ms
      url_with_timeout = "http://localhost:8123/plausible_test?timeout=100"
      og_env = Application.fetch_env!(:plausible, ClickhouseRepo)
      patched_env = Keyword.replace!(og_env, :url, url_with_timeout)
      patch_env(ClickhouseRepo, patched_env)

      start_supervised!({ClickhouseRepo, name: :hurry_up_we_have_timeout})

      task = fn sqls ->
        fn ->
          ClickhouseRepo.put_dynamic_repo(:hurry_up_we_have_timeout)
          for sql <- List.wrap(sqls), do: ClickhouseRepo.query!(sql)
        end
      end

      # to avoid task exits bringing down the test
      Process.flag(:trap_exit, true)

      # one query, taking 50ms, satisfies both ch (100ms) and task (400ms) timeouts
      assert [[%Ch.Result{rows: [[0]]}]] =
               ClickhouseRepo.parallel_tasks([task.("SELECT sleep(0.05)")])

      # one query, taking 150ms, failing ch (100ms) timeout
      assert [{%Mint.TransportError{reason: ch_error_reason}, _stack}] =
               ClickhouseRepo.parallel_tasks([task.("SELECT sleep(0.15)")])

      assert ch_error_reason in [:closed, :timeout]

      # seven 50ms queries in a single task, taking 350ms in total, satisfies both ch (100ms) and task (400ms) timeouts
      assert [
               [
                 %Ch.Result{rows: [[0]]},
                 %Ch.Result{rows: [[0]]},
                 %Ch.Result{rows: [[0]]},
                 %Ch.Result{rows: [[0]]},
                 %Ch.Result{rows: [[0]]},
                 %Ch.Result{rows: [[0]]},
                 %Ch.Result{rows: [[0]]}
               ]
             ] = ClickhouseRepo.parallel_tasks([task.(List.duplicate("SELECT sleep(0.05)", 7))])

      # nine 50ms queries in a single task, taking 450ms in total, failing task (400ms) timeouts
      assert catch_exit(
               ClickhouseRepo.parallel_tasks([task.(List.duplicate("SELECT sleep(0.05)", 9))])
             ) == {:timeout, {Task.Supervised, :stream, [400]}}
    end
  end
end
