defmodule PlausibleWeb.Components.Site.Feature do
  @moduledoc """
  Phoenix Component for rendering a user-facing feature toggle
  capable of flipping booleans in `Plausible.Site` via the `toggle_feature` controller action.
  """
  use PlausibleWeb, :view

  attr(:site, Plausible.Site, required: true)
  attr(:feature_mod, :atom, required: true, values: Plausible.Billing.Feature.list())
  attr(:conn, Plug.Conn, required: true)
  slot(:inner_block)

  def toggle(assigns) do
    assigns =
      assigns
      |> assign(:current_setting, assigns.feature_mod.enabled?(assigns.site))
      |> assign(:disabled?, assigns.feature_mod.check_availability(assigns.site.owner) !== :ok)

    ~H"""
    <div>
      <div class="mt-4 mb-8 flex items-center">
        <.feature_button
          set_to={!@current_setting}
          disabled?={@disabled?}
          conn={@conn}
          site={@site}
          feature_mod={@feature_mod}
        />

        <span class={[
          "ml-2 text-sm font-medium leading-5 mb-1",
          if(assigns.disabled?,
            do: "text-gray-500 dark:text-gray-300",
            else: "text-gray-900 dark:text-gray-100"
          )
        ]}>
          Show <%= @feature_mod.display_name() %> in the Dashboard
        </span>
      </div>
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

  defp feature_button(assigns) do
    ~H"""
    <.form action={target(@site, @feature_mod.toggle_field(), @conn, @set_to)} method="put" for={nil}>
      <button
        type="submit"
        class={[
          "relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full transition-colors ease-in-out duration-200 focus:outline-none focus:ring",
          if(assigns.set_to, do: "bg-gray-200 dark:bg-gray-700", else: "bg-indigo-600"),
          if(assigns.disabled?, do: "cursor-not-allowed")
        ]}
        disabled={@disabled?}
      >
        <span
          aria-hidden="true"
          class={[
            "inline-block h-5 w-5 rounded-full bg-white dark:bg-gray-800 shadow transform transition ease-in-out duration-200",
            if(assigns.set_to, do: "translate-x-0", else: "translate-x-5")
          ]}
        />
      </button>
    </.form>
    """
  end
end
