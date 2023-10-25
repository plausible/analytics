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
          Showing <span class="font-medium"><%= Enum.count(@page.entries) + @extra_count %></span>
          of <span class="font-medium"><%= @page.metadata.total_count + @extra_count %></span>
          <%= @subject %> total
        </p>
      </div>
      <div class="flex-1 flex justify-between sm:justify-end">
        <.pagination_link
          :if={@page.metadata.before != nil}
          uri={@uri}
          cursor={{"before", @page.metadata.before}}
          label="← Previous"
        />
        <.pagination_link
          :if={@page.metadata.after != nil}
          uri={@uri}
          cursor={{"after", @page.metadata.after}}
          label="Next →"
        />
      </div>
    </nav>
    """
  end

  defp pagination_link(assigns) do
    {field, cursor} = assigns.cursor
    params = URI.decode_query(assigns.uri.query, %{field => cursor})
    uri = %{assigns.uri | query: URI.encode_query(params)}

    assigns = assign(assigns, :uri, uri)

    ~H"""
    <a
      href={@uri}
      class="pagination-link relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white dark:bg-gray-100 hover:bg-gray-50"
    >
      <%= @label %>
    </a>
    """
  end
end
