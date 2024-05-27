defmodule Plausible.PaginationTest do
  use Plausible.DataCase, async: true

  alias Plausible.Pagination
  import Ecto.Query

  setup do
    sites = insert_list(12, :site)
    {:ok, %{sites: sites, query: from(s in Plausible.Site, order_by: [desc: :id])}}
  end

  test "default page size", %{query: q} do
    pagination = Pagination.paginate(q, %{}, cursor_fields: [id: :desc])

    assert Enum.count(pagination.entries) == 10
    assert pagination.metadata.after
    assert pagination.metadata.limit == 10
    refute pagination.metadata.before
  end

  test "limit can be overridden", %{query: q} do
    pagination = Pagination.paginate(q, %{"limit" => 3}, cursor_fields: [id: :desc])

    assert Enum.count(pagination.entries) == 3
    assert pagination.metadata.limit == 3
  end

  test "limit exceeds all entries count", %{query: q, sites: sites} do
    pagination = Pagination.paginate(q, %{"limit" => 100}, cursor_fields: [id: :desc])

    assert Enum.count(pagination.entries) == Enum.count(sites)
  end

  test "user provided limit exceeds maximum limit", %{query: q} do
    pagination = Pagination.paginate(q, %{"limit" => 200}, cursor_fields: [id: :desc])
    assert pagination.metadata.limit == 10
  end

  test "limit supplied as a string", %{query: q} do
    pagination = Pagination.paginate(q, %{"limit" => "3"}, cursor_fields: [id: :desc])

    assert Enum.count(pagination.entries) == 3
    assert pagination.metadata.limit == 3
  end

  test "next/prev page", %{query: q} do
    page1 = Pagination.paginate(q, %{"limit" => 3}, cursor_fields: [id: :desc])

    page_after = page1.metadata.after

    page2 =
      Pagination.paginate(q, %{"limit" => 3, "after" => page_after}, cursor_fields: [id: :desc])

    assert page1.entries != page2.entries
    assert Enum.count(page1.entries) == Enum.count(page2.entries)

    page_before = page2.metadata.before

    assert ^page1 =
             Pagination.paginate(q, %{"limit" => 3, "before" => page_before},
               cursor_fields: [id: :desc]
             )
  end
end
