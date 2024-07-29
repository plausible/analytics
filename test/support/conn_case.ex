defmodule PlausibleWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      use Plausible.TestUtils
      use Plausible
      import Plug.Conn
      import Phoenix.ConnTest
      alias PlausibleWeb.Router.Helpers, as: Routes
      import Plausible.Factory

      # The default endpoint for testing
      @endpoint PlausibleWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Plausible.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, {:shared, self()})
    end

    # Tag intended for reducing risk of flaky
    # test result when specifically testing for
    # auth rate limiting. The way `Plausible.RateLimit`
    # does time-based bucketing makes logic simpler
    # at the cost of tests running into flakiness
    # if the fixed time bucket changes right in the
    # middle of test run, effectively resetting the
    # rate limit counter.
    if tags[:auth_rate_limit] do
      now = System.system_time(:millisecond)
      interval = 60_000

      if rem(now, interval) != rem(now + 500, interval) do
        Process.sleep(500)
      end
    end

    # randomize client ip to avoid accidentally hitting
    # rate limiting during tests
    conn =
      Phoenix.ConnTest.build_conn()
      |> Map.put(:secret_key_base, secret_key_base())
      |> Plug.Conn.put_req_header("x-forwarded-for", Plausible.TestUtils.random_ip())

    {:ok, conn: conn}
  end

  defp secret_key_base() do
    :plausible
    |> Application.fetch_env!(PlausibleWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
