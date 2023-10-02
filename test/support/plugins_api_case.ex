defmodule PlausibleWeb.PluginsAPICase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a Plugins API connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint PlausibleWeb.Endpoint

      # Import conveniences for testing with connections
      use Plausible.TestUtils
      import Plug.Conn
      import Phoenix.ConnTest
      import PlausibleWeb.Plugins.API, only: [base_uri: 0]
      import PlausibleWeb.Plugins.API.Spec, only: [spec: 0]
      alias PlausibleWeb.Plugins.API.Router.Helpers, as: Routes
      import Plausible.Factory

      import OpenApiSpex.TestAssertions

      def authenticate(conn, domain, raw_token) do
        conn
        |> Plug.Conn.put_req_header(
          "authorization",
          Plug.BasicAuth.encode_basic_auth(domain, raw_token)
        )
      end
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Plausible.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, {:shared, self()})
    end

    conn = Phoenix.ConnTest.build_conn()

    {:ok, conn: conn}
  end
end
