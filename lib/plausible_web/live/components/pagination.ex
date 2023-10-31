defmodule PlausibleWeb.Live.Components.Pagination do
  @moduledoc """
  Pagination components for LiveViews.
  """
  use Phoenix.Component

  def pagination(assigns) do
    ~H"""
    <nav
      class="px-4 py-3 flex items-center justify-between border-t border-gray-200 dark:border-gray-500 sm:px-6"
      aria-label="Pagination"
    >
      <div class="hidden sm:block">
        <p class="text-sm text-gray-700 dark:text-gray-300">
          <%= render_slot(@inner_block) %>
        </p>
      </div>
      <div class="flex-1 flex justify-between sm:justify-end">
        <.pagination_link uri={@uri} cursor={{"before", @page.metadata.before}} label="← Previous" />
        <.pagination_link
          class="ml-4"
          uri={@uri}
          cursor={{"after", @page.metadata.after}}
          label="Next →"
        />
      </div>
    </nav>
    """
  end

  attr :class, :string, default: nil
  attr :uri, URI, required: true
  attr :cursor, :any, required: true
  attr :label, :string, required: true

  defp pagination_link(assigns) do
    {field, cursor} = assigns.cursor
    active? = not is_nil(cursor)
    params = URI.decode_query(assigns.uri.query, %{field => cursor})
    uri = %{assigns.uri | query: URI.encode_query(params)}

    assigns = assign(assigns, uri: active? && URI.to_string(uri), active?: active?)

    ~H"""
    <.link
      navigate={@uri}
      class={[
        "pagination-link relative inline-flex items-center px-4 py-2 border text-sm font-medium rounded-md",
        if @active? do
          "active button "
        else
          "inactive border-gray-300 text-gray-300 dark:border-gray-500 dark:bg-gray-800 dark:text-gray-600 hover:shadow-none hover:bg-gray-300 cursor-not-allowed"
        end,
        @class
      ]}
    >
      <%= @label %>
    </.link>
    """
  end
end
