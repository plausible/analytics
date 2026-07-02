defmodule PlausibleWeb.Live.AuthLayoutContext do
  @moduledoc false

  def on_mount(_arg, _params, _session, socket) do
    {:cont, socket, layout: {PlausibleWeb.LayoutView, :auth}}
  end
end
