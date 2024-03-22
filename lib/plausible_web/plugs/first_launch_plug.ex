defmodule PlausibleWeb.FirstLaunchPlug do
  @moduledoc """
  Redirects first-launch users to registration page.
  """

  defmodule Test do
    @moduledoc """
    Test helper for setup blocks allowing to skip the plug processing
    """
    @spec skip(map()) :: {:ok, map()}
    def skip(context) do
      conn = Plug.Conn.put_private(context.conn, PlausibleWeb.FirstLaunchPlug, :skip)
      {:ok, Map.put(context, :conn, conn)}
    end
  end

  @behaviour Plug
  alias Plausible.Release

  @impl true
  def init(opts) do
    _path = Keyword.fetch!(opts, :redirect_to)
  end

  @impl true
  def call(%Plug.Conn{private: %{__MODULE__ => :skip}} = conn, _), do: conn
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
