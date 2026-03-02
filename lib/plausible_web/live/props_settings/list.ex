defmodule PlausibleWeb.Live.PropsSettings.List do
  @moduledoc """
  Phoenix LiveComponent module that renders a list of custom properties
  """
  use PlausibleWeb, :live_component

  attr(:props, :list, required: true)
  attr(:domain, :string, required: true)
  attr(:filter_text, :string)

  def render(assigns) do
    assigns = assign(assigns, :searching?, String.trim(assigns.filter_text) != "")

    ~H"""
    <div class="flex flex-col gap-4 sm:gap-6">
      <%= if @searching? or Enum.count(@props) > 0 do %>
        <.filter_bar filter_text={@filter_text} placeholder="Search Properties">
          <.button phx-click="add-prop" mt?={false}>
            Add property
          </.button>
        </.filter_bar>
      <% end %>

      <%= if Enum.count(@props) > 0 do %>
        <.table id="allowed-props" rows={Enum.with_index(@props)}>
          <:tbody :let={{prop, index}}>
            <.td id={"prop-#{index}"}><span class="font-medium">{prop}</span></.td>
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
        <.no_search_results :if={@searching?} />
        <.empty_state :if={not @searching?} />
      <% end %>
    </div>
    """
  end

  defp no_search_results(assigns) do
    ~H"""
    <p class="mt-12 mb-8 text-center text-sm">
      No properties found for this site. Please refine or
      <.styled_link phx-click="reset-filter-text" id="reset-filter-hint">
        reset your search.
      </.styled_link>
    </p>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center pt-5 pb-6 max-w-md mx-auto">
      <h3 class="text-center text-base font-medium text-gray-900 dark:text-gray-100 leading-7">
        Create a custom property
      </h3>
      <p class="text-center text-sm mt-1 text-gray-500 dark:text-gray-400 leading-5 text-pretty">
        Attach custom properties when sending a pageview or an event to create custom metrics.
        <.styled_link href="https://plausible.io/docs/custom-props/introduction" target="_blank">
          Learn more
        </.styled_link>
      </p>
      <.button
        id="add-property-button"
        phx-click="add-prop"
        class="mt-4"
      >
        Add property
      </.button>
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
