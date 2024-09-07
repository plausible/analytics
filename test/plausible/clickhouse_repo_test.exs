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

      query_many = fn sqls ->
        fn ->
          ClickhouseRepo.put_dynamic_repo(:hurry_up_we_have_timeout)
          for sql <- List.wrap(sqls), do: ClickhouseRepo.query!(sql)
        end
      end

      # spawn and monitor the tasks in a separate process to avoid taking down the test
      run_parallel_tasks = fn tasks ->
        {pid, ref} =
          :proc_lib.spawn_opt(
            fn -> ClickhouseRepo.parallel_tasks(List.wrap(tasks)) end,
            [:monitor]
          )

        assert_receive {:DOWN, ^ref, :process, ^pid, exit_reason}, 500
        exit_reason
      end

      # one query, one task, taking 50ms, satisfies both ch (100ms) and task (400ms) timeouts
      assert _exit_reason = :normal = run_parallel_tasks.(query_many.("SELECT sleep(0.05)"))

      # one query, one task, taking 150ms, failing ch (100ms) timeout
      assert {%Mint.TransportError{reason: reason}, _stack} =
               run_parallel_tasks.(query_many.("SELECT sleep(0.15)"))

      assert reason in [:timeout, :closed]

      # seven 50ms queries in a single task, taking 350ms in total, satisfies both ch (100ms) and task (400ms) timeouts
      assert :normal = run_parallel_tasks.(query_many.(List.duplicate("SELECT sleep(0.05)", 7)))

      # nine 50ms queries in a single task, taking 450ms in total, failing task (400ms) timeouts
      assert {:timeout, {Task.Supervised, :stream, [400]}} =
               run_parallel_tasks.(query_many.(List.duplicate("SELECT sleep(0.05)", 9)))
    end
  end
end
