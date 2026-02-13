defmodule PlausibleWeb.Live.CancelFlow do
  @moduledoc """
  Live view for subscription cancel flow
  """
  use PlausibleWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container pt-6">
      Cancel
    </div>
    """
  end
end
