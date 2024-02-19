defmodule Plausible.Imported.CSVImporterTest do
  use Plausible.DataCase, async: true

  doctest Plausible.Imported.CSVImporter, import: true

  @moduletag :minio

  # uses https://min.io
  # docker run -d --rm -p 9000:9000 -p 9001:9001 --name minio minio/minio server /data --console-address ":9001"
  # docker exec minio mc alias set local http://localhost:9000 minioadmin minioadmin
  # docker exec minio mc mb local/imports

  alias Plausible.Imported.{CSVImporter, SiteImport}
  require SiteImport

  describe "new_import/3 and parse_args/1" do
    setup [:create_user, :create_new_site]

    test "parses job args properly", %{user: user, site: site} do
      tables = [
        "imported_browsers",
        "imported_devices",
        "imported_entry_pages",
        "imported_exit_pages",
        "imported_locations",
        "imported_operating_systems",
        "imported_pages",
        "imported_sources",
        "imported_visitors"
      ]

      uploads =
        Enum.map(tables, fn table ->
          filename = "#{table}.csv"
          s3_path = "#{site.id}/#{filename}"
          %{"filename" => filename, "s3_path" => s3_path}
        end)

      assert {:ok, job} = CSVImporter.new_import(site, user, uploads: uploads)

      assert %Oban.Job{args: %{"import_id" => import_id, "uploads" => ^uploads} = args} =
               Repo.reload!(job)

      assert [
               %{
                 id: ^import_id,
                 source: :csv,
                 start_date: ~D[0001-01-01],
                 end_date: ~D[0001-01-01],
                 status: SiteImport.pending()
               }
             ] = Plausible.Imported.list_all_imports(site)

      assert %{imported_data: nil} = Repo.reload!(site)
      assert CSVImporter.parse_args(args) == [uploads: uploads]
    end
  end

  describe "import_data/2" do
    setup [:create_user, :create_new_site]

    test "imports tables from S3"
    test "invalid CSV"
  end
end
