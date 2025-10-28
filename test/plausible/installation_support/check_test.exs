defmodule Plausible.InstallationSupport.CheckTest do
  use Plausible
  use Plausible.DataCase, async: true

  @moduletag :ee_only

  on_ee do
    import ExUnit.CaptureLog
    import Plausible.AssertMatches
    alias Plausible.InstallationSupport.{State, Verification}

    @moduletag :capture_log

    test "a check that raises" do
      defmodule FaultyCheckRaise do
        use Plausible.InstallationSupport.Check

        @impl true
        def report_progress_as, do: "Faulty check"

        @impl true
        def perform(_), do: raise("boom")
      end

      state = %State{
        url: "https://example.com",
        report_to: self(),
        diagnostics: %Verification.Diagnostics{}
      }

      {result, log} =
        with_log(fn ->
          FaultyCheckRaise.perform_safe(state, [])
        end)

      assert log =~
               ~s|Error running check Plausible.InstallationSupport.CheckTest.FaultyCheckRaise on https://example.com: %RuntimeError{message: "boom"}|

      assert_matches %Verification.Diagnostics{
                       service_error: %{
                         code: :internal_check_error,
                         extra: %RuntimeError{message: "boom"}
                       }
                     } =
                       result.diagnostics
    end

    test "a check that throws" do
      defmodule FaultyCheckThrow do
        use Plausible.InstallationSupport.Check

        @impl true
        def report_progress_as, do: "Faulty check"

        @impl true
        def perform(_), do: :erlang.throw(:boom)
      end

      state = %State{
        url: "https://example.com",
        report_to: self(),
        diagnostics: %Verification.Diagnostics{}
      }

      {result, log} =
        with_log(fn ->
          FaultyCheckThrow.perform_safe(state, [])
        end)

      assert log =~
               ~s|Error running check Plausible.InstallationSupport.CheckTest.FaultyCheckThrow on https://example.com: :boom|

      assert_matches %Verification.Diagnostics{
                       service_error: %{code: :internal_check_error, extra: :boom}
                     } = result.diagnostics
    end

    test "a check that times out" do
      defmodule FaultyCheckTimeout do
        use Plausible.InstallationSupport.Check

        @impl true
        def report_progress_as, do: "Faulty check"

        @impl true
        def perform(_), do: :timer.sleep(500)
      end

      state = %State{
        url: "https://example.com",
        report_to: self(),
        diagnostics: %Verification.Diagnostics{}
      }

      result = FaultyCheckTimeout.perform_safe(state, timeout: 100)

      assert_matches %Verification.Diagnostics{
                       service_error: %{
                         code: :internal_check_timeout,
                         extra: "FaultyCheckTimeout timed out after 100ms"
                       }
                     } = result.diagnostics
    end
  end
end
