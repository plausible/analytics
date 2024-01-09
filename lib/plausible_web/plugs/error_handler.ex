defmodule PlausibleWeb.Plugs.ErrorHandler do
  @moduledoc """
    A thin macro wrapper around Plug.ErrorHandler that adds Sentry context
    containing a readable support hash presented to the users.
    To be used in the user-facing APIs, so that we don't leak internal
    server errors.

    Usage: `use PlausibleWeb.Plugs.ErrorHandler`
  """
  defmacro __using__(_) do
    quote do
      use Plug.ErrorHandler

      @impl Plug.ErrorHandler
      def handle_errors(conn, %{kind: kind, reason: reason}) do
        json(conn, %{error: "internal server error"})
      end
    end
  end
end
