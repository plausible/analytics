defmodule PlausibleWeb.Live.PropsSettings.List do
  @moduledoc """
  Phoenix LiveComponent module that renders a list of custom properties
  """
  use Phoenix.LiveComponent
  use Phoenix.HTML
  import PlausibleWeb.Components.Generic

  attr(:props, :list, required: true)
  attr(:domain, :string, required: true)
  attr(:filter_text, :string)

  def render(assigns) do
    ~H"""
    <div>
      <.filter_bar filter_text={@filter_text} placeholder="Search Properties">
        <.button phx-click="add-prop" mt?={false}>
          Add Property
        </.button>
      </.filter_bar>
      <%= if is_list(@props) && length(@props) > 0 do %>
        <.table id="allowed-props" rows={Enum.with_index(@props)}>
          <:tbody :let={{prop, index}}>
            <.td id={"prop-#{index}"}><span class="font-medium"><%= prop %></span></.td>
            <.td actions>
              <.delete_button
                id={"disallow-prop-#{prop}"}
                data-confirm={delete_confirmation_text(prop)}
                phx-click="disallow-prop"
                phx-value-prop={prop}
                aria-label={"Remove #{prop} property"}
              />
            </.td>
          </:tbody>
        </.table>
      <% else %>
        <p class="mt-12 mb-8 text-center text-sm">
          <span :if={String.trim(@filter_text) != ""}>
            No properties found for this site. Please refine or
            <.styled_link phx-click="reset-filter-text" id="reset-filter-hint">
              reset your search.
            </.styled_link>
          </span>
          <span :if={String.trim(@filter_text) == "" && Enum.empty?(@props)}>
            No properties configured for this site.
          </span>
        </p>
      <% end %>
    </div>
    """
  end

  defp delete_confirmation_text(prop) do
    """
    Are you sure you want to remove the following property:

    #{prop}

    This will just affect the UI, all of your analytics data will stay intact.
    """
  end
end
