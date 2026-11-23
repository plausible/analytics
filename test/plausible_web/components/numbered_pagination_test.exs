defmodule PlausibleWeb.Components.NumberedPaginationTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Plausible.Test.Support.HTML

  alias PlausibleWeb.Components.NumberedPagination

  describe "render/1" do
    test "keeps the query parameters of href in the page links" do
      html = render_pagination(page_number: 5, total_pages: 10, href: "/items?filter=all")

      assert links(html) == [
               {"Previous", "/items?filter=all&page=4"},
               {"1", "/items?filter=all&page=1"},
               {"10", "/items?filter=all&page=10"},
               {"Next", "/items?filter=all&page=6"}
             ]
    end

    test "does not render a previous link on the first page" do
      html = render_pagination(page_number: 1, total_pages: 3)

      assert links(html) == [
               {"2", "/items?page=2"},
               {"3", "/items?page=3"},
               {"Next", "/items?page=2"}
             ]
    end

    test "does not render a next link on the last page" do
      html = render_pagination(page_number: 3, total_pages: 3)

      assert links(html) == [
               {"Previous", "/items?page=2"},
               {"1", "/items?page=1"},
               {"2", "/items?page=2"}
             ]
    end

    for {page_number, total_pages, expected} <- [
          # No truncation when total_pages <= 5
          {1, 1, ["[1]"]},
          {3, 3, ["1", "2", "[3]"]},
          {1, 5, ["[1]", "2", "3", "4", "5"]},
          {5, 5, ["1", "2", "3", "4", "[5]"]},
          # On the first three pages, truncates towards the end
          {1, 6, ["[1]", "2", "3", "...", "6"]},
          {2, 6, ["1", "[2]", "3", "...", "6"]},
          {3, 6, ["1", "2", "[3]", "...", "6"]},
          # On the last three pages, truncates from the beginning
          {4, 6, ["1", "...", "[4]", "5", "6"]},
          {5, 6, ["1", "...", "4", "[5]", "6"]},
          {6, 6, ["1", "...", "4", "5", "[6]"]},
          # Deep in the middle, truncates both sides
          {4, 10, ["1", "...", "[4]", "...", "10"]},
          {7, 10, ["1", "...", "[7]", "...", "10"]}
        ] do
      test "page #{page_number} of #{total_pages} shows #{inspect(expected)}" do
        html =
          render_pagination(page_number: unquote(page_number), total_pages: unquote(total_pages))

        assert page_items(html) == unquote(expected)
      end
    end
  end

  defp render_pagination(opts) do
    render_component(&NumberedPagination.render/1,
      href: Keyword.get(opts, :href, "/items"),
      page_number: Keyword.fetch!(opts, :page_number),
      total_pages: Keyword.fetch!(opts, :total_pages)
    )
  end

  defp links(html) do
    html
    |> find("nav a")
    |> Enum.map(&{text(&1), text_of_attr(&1, "href")})
  end

  defp page_items(html) do
    html
    |> find("nav > div > *")
    |> Enum.map(fn item ->
      if text_of_attr(item, "aria-current") == "page",
        do: "[#{text(item)}]",
        else: text(item)
    end)
    |> Enum.reject(&(&1 in ["Previous", "Next"]))
  end
end
