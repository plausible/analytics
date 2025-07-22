defmodule Plausible.Audit.LiveContext do
  @moduledoc """
  LiveView `on_mount` callback to provide audit context
  """

  defmacro __using__(_) do
    quote do
      on_mount Plausible.Audit.LiveContext
    end
  end

  def on_mount(:default, _params, _session, socket) do
    if Phoenix.LiveView.connected?(socket) do
      Plausible.Audit.set_context(%{
        current_user: socket.assigns[:current_user],
        current_team: socket.assigns[:current_team]
      })
    end

    {:cont, socket}
  end
end
