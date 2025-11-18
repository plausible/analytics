defmodule PlausibleWeb.Components.Site.Feature do
  @moduledoc """
  Phoenix Component for rendering a user-facing feature toggle
  capable of flipping booleans in `Plausible.Site` via the `toggle_feature` controller action.
  """
  use PlausibleWeb, :view

  attr(:site, Plausible.Site, required: true)
  attr(:feature_mod, :atom, required: true, values: Plausible.Billing.Feature.list())
  attr(:conn, :any, default: nil)
  attr(:current_user, :any, default: nil)
  attr(:class, :any, default: nil)
  slot(:inner_block)

  def toggle(%{conn: %Plug.Conn{}} = assigns) do
    assigns =
      assigns
      |> assign(:current_setting, assigns.feature_mod.enabled?(assigns.site))
      |> assign(:disabled?, assigns.feature_mod.check_availability(assigns.site.team) !== :ok)

    ~H"""
    <div class="mt-4">
      <.form
        action={target(@site, @feature_mod.toggle_field(), @conn, !@current_setting)}
        method="put"
        for={nil}
        class={@class}
      >
        <.toggle_submit set_to={@current_setting} disabled?={@disabled?}>
          Show in dashboard
        </.toggle_submit>
      </.form>

      <div :if={@current_setting}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  def toggle(assigns) do
    ~H"""
    <.live_component
      module={PlausibleWeb.Components.Site.Feature.ToggleLive}
      id={"feature-toggle-#{@site.id}-#{@feature_mod}"}
      site={@site}
      feature_mod={@feature_mod}
      current_user={@current_user}
      class={@class}
    >
      {render_slot(@inner_block)}
    </.live_component>
    """
  end

  defp target(site, setting, conn, set_to) when is_boolean(set_to) do
    r = conn.request_path
    Routes.site_path(conn, :update_feature_visibility, site.domain, setting, r: r, set: set_to)
  end
end
