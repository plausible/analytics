defmodule PlausibleWeb.Live.AuthLayoutContext do
  @moduledoc false

  import Phoenix.Component

  def on_mount(_arg, _params, _session, socket) do
    socket =
      assign(socket,
        hide_header?: true,
        hide_footer?: true,
        disable_global_notices?: true
      )

    {:cont, socket, layout: {PlausibleWeb.LayoutView, :auth}}
  end
end
