defmodule PlausibleWeb.Components.NumberedPagination do
  @moduledoc """
  Pagination with page number links and baked in truncation logic.

  Currently renders plain `href` links, so it only works on dead views.
  """
  use Phoenix.Component

  attr(:href, :string, required: true)
  attr(:page_number, :integer, required: true)
  attr(:total_pages, :integer, required: true)
  attr(:class, :any, default: nil)

  def render(assigns) do
    assigns = assign(assigns, items: page_items(assigns.page_number, assigns.total_pages))

    ~H"""
    <nav
      aria-label="Pagination"
      class={[
        "flex items-center justify-between border-t border-gray-200 dark:border-gray-700",
        @class
      ]}
    >
      <div class="-mt-px flex w-0 flex-1">
        <.page_arrow
          :if={@page_number > 1}
          direction={:previous}
          href={page_href(@href, @page_number - 1)}
        />
      </div>
      <div class="-mt-px flex">
        <.page_item :for={item <- @items} item={item} page_number={@page_number} href={@href} />
      </div>
      <div class="-mt-px flex w-0 flex-1 justify-end">
        <.page_arrow
          :if={@page_number < @total_pages}
          direction={:next}
          href={page_href(@href, @page_number + 1)}
        />
      </div>
    </nav>
    """
  end

  attr(:item, :any, required: true)
  attr(:page_number, :integer, required: true)
  attr(:href, :string, required: true)

  defp page_item(%{item: :ellipsis} = assigns) do
    ~H"""
    <span class="inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 dark:text-gray-400">
      ...
    </span>
    """
  end

  defp page_item(%{item: item, page_number: item} = assigns) do
    ~H"""
    <span
      aria-current="page"
      class="inline-flex items-center border-t-2 border-indigo-500 px-4 pt-4 text-sm font-medium text-indigo-600 dark:text-indigo-400"
    >
      {@item}
    </span>
    """
  end

  defp page_item(assigns) do
    ~H"""
    <a
      href={page_href(@href, @item)}
      class="inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 dark:text-gray-400 hover:border-gray-300 dark:hover:border-gray-600 hover:text-gray-700 dark:hover:text-gray-200"
    >
      {@item}
    </a>
    """
  end

  attr(:direction, :atom, values: [:previous, :next], required: true)
  attr(:href, :string, required: true)

  defp page_arrow(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "group inline-flex items-center gap-3 border-t-2 border-transparent pt-4 text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200",
        if(@direction == :previous, do: "pr-1", else: "pl-1")
      ]}
    >
      <Heroicons.arrow_long_left
        :if={@direction == :previous}
        mini
        class="size-5 text-gray-400 dark:text-gray-500 group-hover:text-gray-500 dark:group-hover:text-gray-400"
      />
      <span class="sr-only sm:not-sr-only">
        {if @direction == :previous, do: "Previous", else: "Next"}
      </span>
      <Heroicons.arrow_long_right
        :if={@direction == :next}
        mini
        class="size-5 text-gray-400 dark:text-gray-500 group-hover:text-gray-500 dark:group-hover:text-gray-400"
      />
    </a>
    """
  end

  defp page_items(_page_number, total_pages) when total_pages <= 5 do
    Enum.to_list(1..total_pages)
  end

  defp page_items(page_number, total_pages) when page_number <= 3 do
    [1, 2, 3, :ellipsis, total_pages]
  end

  defp page_items(page_number, total_pages) when page_number >= total_pages - 2 do
    [1, :ellipsis, total_pages - 2, total_pages - 1, total_pages]
  end

  defp page_items(page_number, total_pages) do
    [1, :ellipsis, page_number, :ellipsis, total_pages]
  end

  defp page_href(href, page_number) do
    uri = URI.parse(href)

    query =
      (uri.query || "")
      |> URI.decode_query()
      |> Map.put("page", page_number)
      |> URI.encode_query()

    URI.to_string(%{uri | query: query})
  end
end
