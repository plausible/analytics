defmodule Plausible.Imported.BufferTest do
  use Plausible.DataCase, async: false

  import Ecto.Query
  alias Plausible.Imported.Buffer

  setup [:create_user, :create_site, :set_buffer_size]

  defp set_buffer_size(_setup_args) do
    imported_setting = Application.fetch_env!(:plausible, :imported)
    patch_env(:imported, Keyword.put(imported_setting, :max_buffer_size, 10))
    :ok
  end

  defp imported_count(%{id: site_id}, table_name) do
    table_name
    |> from()
    |> where([record], record.site_id == ^site_id)
    |> Plausible.ClickhouseRepo.aggregate(:count)
  end

  defp build_records(count, factory_name, site) do
    count
    |> build_list(factory_name, site_id: site.id)
    |> Enum.map(&Map.drop(&1, [:table]))
  end

  @tag :slow
  test "insert_many/3 flushes when buffer reaches limit", %{site: site} do
    {:ok, pid} = Buffer.start_link()

    imported_visitors = build_records(9, :imported_visitors, site)
    assert :ok == Buffer.insert_many(pid, "imported_visitors", imported_visitors)
    assert Buffer.size(pid, "imported_visitors") == 9
    assert imported_count(site, "imported_visitors") == 0, "expected not to have flushed"

    imported_visitors = build_records(1, :imported_visitors, site)
    assert :ok == Buffer.insert_many(pid, "imported_visitors", imported_visitors)
    assert Buffer.size(pid, "imported_visitors") == 0
    assert imported_count(site, "imported_visitors") == 10, "expected to have flushed"
  end

  @tag :slow
  test "insert_many/3 uses separate buffers for each table", %{site: site} do
    {:ok, pid} = Buffer.start_link()

    imported_visitors = build_records(9, :imported_visitors, site)
    assert :ok == Buffer.insert_many(pid, "imported_visitors", imported_visitors)
    assert Buffer.size(pid, "imported_visitors") == 9
    assert imported_count(site, "imported_visitors") == 0, "expected not to have flushed"

    imported_sources = build_records(1, :imported_sources, site)
    assert :ok == Buffer.insert_many(pid, "imported_sources", imported_sources)
    assert Buffer.size(pid, "imported_sources") == 1
    assert imported_count(site, "imported_visitors") == 0, "expected not to have flushed"

    imported_visitors = build_records(1, :imported_visitors, site)
    assert :ok == Buffer.insert_many(pid, "imported_visitors", imported_visitors)
    assert Buffer.size(pid, "imported_visitors") == 0
    assert imported_count(site, "imported_visitors") == 10, "expected to have flushed"

    imported_sources = build_records(9, :imported_sources, site)
    assert :ok == Buffer.insert_many(pid, "imported_sources", imported_sources)
    assert Buffer.size(pid, "imported_sources") == 0
    assert imported_count(site, "imported_sources") == 10, "expected to have flushed"
  end

  test "insert_many/3 flushes buffer automatically with many records", %{site: site} do
    {:ok, pid} = Buffer.start_link()

    imported_visitors = build_records(50, :imported_visitors, site)
    assert :ok == Buffer.insert_many(pid, "imported_visitors", imported_visitors)
    assert Buffer.size(pid, "imported_visitors") == 0
    assert imported_count(site, "imported_visitors") == 50, "expected to have flushed"
  end

  @tag :slow
  test "flush/2 flushes all buffers", %{site: site} do
    {:ok, pid} = Buffer.start_link()

    imported_sources = build_records(1, :imported_sources, site)
    Buffer.insert_many(pid, "imported_sources", imported_sources)

    imported_visitors = build_records(1, :imported_visitors, site)
    Buffer.insert_many(pid, "imported_visitors", imported_visitors)

    imported_operating_systems = build_records(2, :imported_operating_systems, site)
    Buffer.insert_many(pid, "imported_operating_systems", imported_operating_systems)

    assert :ok == Buffer.flush(pid, :timer.seconds(4))

    assert Buffer.size(pid, "imported_sources") == 0
    assert Buffer.size(pid, "imported_visitors") == 0
    assert Buffer.size(pid, "imported_operating_systems") == 0

    assert imported_count(site, "imported_sources") == 1
    assert imported_count(site, "imported_visitors") == 1
    assert imported_count(site, "imported_operating_systems") == 2
  end
end
