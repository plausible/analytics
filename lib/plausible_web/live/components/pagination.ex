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
        <.pagination_link
          page_number={@page_number}
          total_pages={@total_pages}
          uri={@uri}
          type={:prev}
        />
        <.pagination_link
          page_number={@page_number}
          total_pages={@total_pages}
          class="ml-4"
          uri={@uri}
          type={:next}
        />
      </div>
    </nav>
    """
  end

  attr :class, :string, default: nil
  attr :uri, URI, required: true
  attr :type, :atom, required: true
  attr :page_number, :integer, required: true
  attr :total_pages, :integer, required: true

  defp pagination_link(assigns) do
    {active?, uri} =
      case {assigns.type, assigns.page_number, assigns.total_pages} do
        {:next, n, total} when n < total ->
          params = URI.decode_query(assigns.uri.query, %{"page" => n + 1})
          {true, %{assigns.uri | query: URI.encode_query(params)}}

        {:prev, n, _total} when n > 1 ->
          params = URI.decode_query(assigns.uri.query, %{"page" => n - 1})
          {true, %{assigns.uri | query: URI.encode_query(params)}}

        {_, _, _} ->
          {false, nil}
      end

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
      <span :if={@type == :prev}>← Previous</span>
      <span :if={@type == :next}>Next →</span>
    </.link>
    """
  end
end
