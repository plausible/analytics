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
      import Plausible.AssertMatches

      # The default endpoint for testing
      @endpoint PlausibleWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Plausible.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, {:shared, self()})
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
