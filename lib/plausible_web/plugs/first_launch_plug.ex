defmodule PlausibleWeb.FirstLaunchPlug do
  @moduledoc """
  Redirects first-launch users to registration page.
  """

  @behaviour Plug
  alias Plausible.Release

  @impl true
  def init(opts) do
    _path = Keyword.fetch!(opts, :redirect_to)
  end

  @impl true
  def call(%Plug.Conn{request_path: path} = conn, path), do: conn

  def call(conn, redirect_to) do
    if Release.should_be_first_launch?() do
      conn
      |> Phoenix.Controller.redirect(to: redirect_to)
      |> Plug.Conn.halt()
    else
      conn
    end
  end
end
