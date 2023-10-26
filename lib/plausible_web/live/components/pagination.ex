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
        <.pagination_link uri={@uri} cursor={{"after", @page.metadata.after}} label="Next →" />
      </div>
    </nav>
    """
  end

  defp pagination_link(assigns) do
    {field, cursor} = assigns.cursor
    active? = not is_nil(cursor)
    params = URI.decode_query(assigns.uri.query, %{field => cursor})
    uri = %{assigns.uri | query: URI.encode_query(params)}

    assigns = assign(assigns, uri: active? && uri, active?: active?)

    ~H"""
    <a
      href={@uri}
      class={[
        "pagination-link relative inline-flex items-center px-4 py-2 border text-sm font-medium rounded-md bg-white dark:bg-gray-100",
        if @active? do
          "border-gray-300 text-gray-700 hover:bg-gray-50"
        else
          "border-gray-300 text-gray-300 dark:bg-gray-600 hover:shadow-none hover:bg-gray-300 cursor-not-allowed"
        end
      ]}
    >
      <%= @label %>
    </a>
    """
  end
end
