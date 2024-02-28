defmodule Plausible.ImportedTest do
  use Plausible.DataCase
  use Plausible

  alias Plausible.Imported

  describe "list_all_imports/1" do
    test "returns empty when there are no imports" do
      site = insert(:site)

      assert Imported.list_all_imports(site) == []
    end

    test "returns imports in various states" do
      site = insert(:site)

      _rogue_import = insert(:site_import)

      import1 = insert(:site_import, site: site, status: :pending)
      import2 = insert(:site_import, site: site, status: :importing)
      import3 = insert(:site_import, site: site, status: :completed)
      import4 = insert(:site_import, site: site, status: :failed)

      assert [%{id: id1}, %{id: id2}, %{id: id3}, %{id: id4}] = Imported.list_all_imports(site)

      ids = [id1, id2, id3, id4]

      assert import1.id in ids
      assert import2.id in ids
      assert import3.id in ids
      assert import4.id in ids
    end

    test "returns one legacy import when present with respective site import entry" do
      site = insert(:site)
      {:ok, opts} = add_imported_data(%{site: site})
      site = Map.new(opts).site
      site_import = insert(:site_import, site: site, legacy: true)
      site_import_id = site_import.id

      assert [%{id: ^site_import_id}] = Imported.list_all_imports(site)
    end

    test "returns legacy import without respective site import entry" do
      site = insert(:site)
      {:ok, opts} = add_imported_data(%{site: site})
      site = Map.new(opts).site
      imported_start_date = site.imported_data.start_date
      imported_end_date = site.imported_data.end_date

      assert [
               %{
                 id: 0,
                 source: :universal_analytics,
                 start_date: ^imported_start_date,
                 end_date: ^imported_end_date,
                 status: :completed
               }
             ] = Imported.list_all_imports(site)
    end
  end
end
