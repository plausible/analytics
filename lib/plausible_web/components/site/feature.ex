defmodule PlausibleWeb.Components.Site.Feature do
  @moduledoc """
  Phoenix Component for rendering a user-facing feature toggle
  capable of flipping booleans in `Plausible.Site` via the `toggle_feature` controller action.
  """
  use PlausibleWeb, :view

  attr(:site, Plausible.Site, required: true)
  attr(:feature_mod, :atom, required: true, values: Plausible.Billing.Feature.list())
  attr(:conn, Plug.Conn, required: true)
  attr(:class, :any, default: nil)
  slot(:inner_block)

  def toggle(assigns) do
    assigns =
      assigns
      |> assign(:current_setting, assigns.feature_mod.enabled?(assigns.site))
      |> assign(:disabled?, assigns.feature_mod.check_availability(assigns.site.owner) !== :ok)

    ~H"""
    <div>
      <.form
        action={target(@site, @feature_mod.toggle_field(), @conn, !@current_setting)}
        method="put"
        for={nil}
        class={@class}
      >
        <.toggle_submit set_to={@current_setting} disabled?={@disabled?}>
          Show <%= @feature_mod.display_name() %> in the Dashboard
        </.toggle_submit>
      </.form>

      <div :if={@current_setting}>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def target(site, setting, conn, set_to) when is_boolean(set_to) do
    r = conn.request_path
    Routes.site_path(conn, :update_feature_visibility, site.domain, setting, r: r, set: set_to)
  end
end
