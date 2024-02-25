defmodule Plausible.Imported.CSVImporterTest do
  use Plausible.DataCase, async: true
  alias Plausible.Imported.{CSVImporter, SiteImport}
  alias Testcontainers.MinioContainer
  require SiteImport

  @moduletag :minio

  setup_all do
    Testcontainers.start_link()

    {:ok, minio} = Testcontainers.start_container(MinioContainer.new())
    on_exit(fn -> :ok = Testcontainers.stop_container(minio.container_id) end)
    connection_opts = MinioContainer.connection_opts(minio)

    s3 = fn op -> ExAws.request!(op, connection_opts) end
    s3.(ExAws.S3.put_bucket("imports", "us-east-1"))
    on_exit(fn -> s3.(ExAws.S3.delete_bucket("imports")) end)

    {:ok, container: minio, s3: s3}
  end

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

          %{
            "filename" => filename,
            "s3_url" => "https://bucket-name.s3.eu-north-1.amazonaws.com/#{site.id}/#{filename}"
          }
        end)

      assert {:ok, job} =
               CSVImporter.new_import(site, user,
                 # to satisfy the non null constraints on the table I'm providing "0" dates (according to ClickHouse)
                 start_date: ~D[1970-01-01],
                 end_date: ~D[1970-01-01],
                 uploads: uploads
               )

      assert %Oban.Job{args: %{"import_id" => import_id, "uploads" => ^uploads} = args} =
               Repo.reload!(job)

      assert [
               %{
                 id: ^import_id,
                 source: :csv,
                 start_date: ~D[1970-01-01],
                 end_date: ~D[1970-01-01],
                 status: SiteImport.pending()
               }
             ] = Plausible.Imported.list_all_imports(site)

      assert %{imported_data: nil} = Repo.reload!(site)
      assert CSVImporter.parse_args(args) == [uploads: uploads]
    end
  end

  describe "import_data/2" do
    setup [:create_user, :create_new_site]

    test "imports tables from S3", %{site: site, user: user, s3: s3, container: minio} do
      csvs = [
        %{
          name: "imported_browsers.csv",
          body: """
          "date","browser","visitors","visits","visit_duration","bounces"
          "2021-12-30","Amazon Silk",2,2,0,2
          "2021-12-30","Chrome",31,32,329,29
          "2021-12-30","Edge",3,3,0,3
          "2021-12-30","Firefox",1,1,0,1
          "2021-12-30","Internet Explorer",1,1,0,1
          "2021-12-30","Mobile App",2,2,0,2
          "2021-12-30","Mobile App",4,4,0,4
          "2021-12-30","Mobile App",1,1,0,1
          "2021-12-30","Safari",32,36,0,36
          "2021-12-30","Samsung Internet",2,2,0,2
          "2021-12-30","UC Browser",1,1,0,1
          "2021-12-31","Chrome",24,25,75,23
          "2021-12-31","Edge",3,3,0,3
          "2021-12-31","Firefox",1,1,466,0
          "2021-12-31","Mobile App",4,5,0,5
          "2021-12-31","Mobile App",4,4,0,4
          "2021-12-31","Mobile App",1,1,85,0
          "2021-12-31","Safari",37,45,1957,42
          "2021-12-31","Samsung Internet",1,1,199,0
          """
        },
        %{
          name: "imported_devices.csv",
          body: """
          "date","device","visitors","visits","visit_duration","bounces"
          "2021-12-30","Desktop",25,28,75,27
          "2021-12-30","Mobile",49,51,254,49
          "2021-12-30","Tablet",6,6,0,6
          "2021-12-31","Desktop",20,26,496,24
          "2021-12-31","Mobile",50,54,1842,49
          "2021-12-31","Tablet",5,5,444,4
          "2022-01-01","Desktop",33,34,1117,32
          "2022-01-01","Mobile",55,60,306,54
          "2022-01-01","Tablet",8,8,419,7
          "2022-01-02","Desktop",28,28,86,26
          "2022-01-02","Mobile",66,73,2450,65
          "2022-01-02","Tablet",9,9,0,9
          """
        },
        %{
          name: "imported_entry_pages.csv",
          body: """
          "date","visitors","entrances","visit_duration","bounces","entry_page"
          "2021-12-30",6,6,0,6,"/14776416252794997127"
          "2021-12-30",1,1,0,1,"/15455127321321119046"
          "2021-12-30",1,1,43,0,"/10399835914295020763"
          "2021-12-30",1,1,0,1,"/9102354072466236765"
          "2021-12-30",1,1,0,1,"/1586391735863371077"
          "2021-12-30",1,1,0,1,"/3457026921000639206"
          "2021-12-30",2,3,0,3,"/6077502147861556415"
          "2021-12-30",1,1,0,1,"/14280570555317344651"
          "2021-12-30",3,3,0,3,"/5284268072698982201"
          "2021-12-30",1,1,0,1,"/7478911940502018071"
          "2021-12-30",1,1,0,1,"/6402607186523575652"
          "2021-12-30",2,2,0,2,"/9962503789684934900"
          "2021-12-30",8,10,0,10,"/13595620304963848161"
          "2021-12-30",2,2,0,2,"/17019199732013993436"
          "2021-12-30",31,31,211,30,"/9874837495456455794"
          "2021-12-31",4,4,0,4,"/14776416252794997127"
          "2021-12-31",1,1,0,1,"/8738789417178304429"
          "2021-12-31",1,1,0,1,"/7445073500314667742"
          "2021-12-31",1,1,0,1,"/4897404798407749335"
          "2021-12-31",1,1,45,0,"/11263893625781431659"
          "2021-12-31",1,1,0,1,"/16478773157730928089"
          "2021-12-31",1,1,0,1,"/1710995203264225236"
          "2021-12-31",1,1,0,1,"/14280570555317344651"
          "2021-12-31",4,5,444,4,"/5284268072698982201"
          "2021-12-31",2,2,466,1,"/7478911940502018071"
          "2021-12-31",9,16,1455,15,"/13595620304963848161"
          "2021-12-31",25,25,88,23,"/9874837495456455794"
          """
        },
        %{
          name: "imported_exit_pages.csv",
          body: """
          "date","visitors","exits","exit_page"
          "2021-12-30",6,6,"/14776416252794997127"
          "2021-12-30",1,1,"/15455127321321119046"
          "2021-12-30",1,1,"/9102354072466236765"
          "2021-12-30",1,1,"/4457889102355683190"
          "2021-12-30",1,1,"/12105301321223776356"
          "2021-12-30",1,2,"/1526239929864936398"
          "2021-12-30",1,1,"/7478911940502018071"
          "2021-12-30",1,1,"/6402607186523575652"
          "2021-12-30",2,2,"/9962503789684934900"
          "2021-12-30",8,10,"/13595620304963848161"
          "2021-12-30",2,2,"/17019199732013993436"
          "2021-12-30",32,32,"/9874837495456455794"
          "2021-12-31",4,4,"/14776416252794997127"
          "2021-12-31",1,1,"/8738789417178304429"
          "2021-12-31",1,1,"/7445073500314667742"
          "2021-12-31",1,1,"/4897404798407749335"
          "2021-12-31",1,1,"/11263893625781431659"
          "2021-12-31",1,1,"/16478773157730928089"
          "2021-12-31",1,1,"/1710995203264225236"
          """
        },
        %{
          name: "imported_locations.csv",
          body: """
          "date","country","region","city","visitors","visits","visit_duration","bounces"
          "2021-12-30","AU","",0,1,1,43,0
          "2021-12-30","AU","",2078025,3,4,211,3
          "2021-12-30","AU","",2147714,2,2,0,2
          "2021-12-30","AU","",2158177,2,2,0,2
          "2021-12-30","AU","",2174003,1,1,0,1
          "2021-12-30","BE","",0,1,1,0,1
          "2021-12-30","BE","",2792196,1,1,0,1
          "2021-12-30","BR","",0,1,1,0,1
          "2021-12-30","CA","",0,1,1,0,1
          "2021-12-30","PL","",0,1,1,0,1
          "2021-12-30","PL","",756135,1,1,0,1
          "2021-12-30","US","",0,1,1,0,1
          "2021-12-30","US","",0,1,1,0,1
          "2021-12-30","US","",0,1,1,0,1
          "2021-12-30","US","",0,1,1,0,1
          "2021-12-30","US","",4063926,1,1,0,1
          "2021-12-30","US","",4074013,1,3,0,3
          "2021-12-30","US","",5089478,1,1,0,1
          "2021-12-31","AU","",2147714,3,3,0,3
          "2021-12-31","AU","",2158177,2,2,0,2
          "2021-12-31","CA","",0,1,1,0,1
          "2021-12-31","IT","",3176959,1,1,85,0
          "2021-12-31","KR","",1835848,1,1,0,1
          "2021-12-31","LV","",456172,1,1,0,1
          "2021-12-31","MX","",3530757,2,3,0,3
          "2021-12-31","NL","",0,1,1,0,1
          "2021-12-31","NL","",0,1,2,0,2
          "2021-12-31","NL","",2745321,1,1,0,1
          "2021-12-31","NO","",0,1,1,199,0
          "2021-12-31","SE","",0,1,1,0,1
          "2021-12-31","SG","",1880252,1,1,0,1
          """
        },
        %{
          name: "imported_operating_systems.csv",
          body: """
          "date","operating_system","visitors","visits","visit_duration","bounces"
          "2021-12-30","Android",25,26,254,24
          "2021-12-30","Mac",13,16,0,16
          "2021-12-30","Windows",12,12,75,11
          "2021-12-30","iOS",30,31,0,31
          "2021-12-31","Android",15,16,329,13
          "2021-12-31","Mac",13,19,0,19
          "2021-12-31","Windows",7,7,496,5
          "2021-12-31","iOS",40,43,1957,40
          "2022-01-01","",17,18,0,18
          "2022-01-01","Android",25,28,32,26
          "2022-01-01","Chrome OS",1,1,0,1
          "2022-01-01","Mac",6,6,0,6
          "2022-01-01","Windows",9,9,1117,7
          "2022-01-01","iOS",38,40,693,35
          """
        },
        %{
          name: "imported_pages.csv",
          body: """
          "date","visitors","pageviews","exits","time_on_page","hostname","page"
          "2021-12-30",1,1,0,43,"lucky.numbers.com","/14776416252794997127"
          "2021-12-30",1,1,1,0,"lucky.numbers.com","/14776416252794997127"
          "2021-12-30",6,6,6,0,"lucky.numbers.com","/14776416252794997127"
          "2021-12-30",1,1,1,0,"lucky.numbers.com","/9102354072466236765"
          "2021-12-30",1,1,1,0,"lucky.numbers.com","/7478911940502018071"
          "2021-12-30",1,1,1,0,"lucky.numbers.com","/6402607186523575652"
          "2021-12-30",2,2,2,0,"lucky.numbers.com","/9962503789684934900"
          "2021-12-30",8,10,10,0,"lucky.numbers.com","/13595620304963848161"
          "2021-12-30",2,2,2,0,"lucky.numbers.com","/17019199732013993436"
          "2021-12-30",32,33,32,211,"lucky.numbers.com","/9874837495456455794"
          "2021-12-31",4,4,4,0,"lucky.numbers.com","/14776416252794997127"
          "2021-12-31",1,1,1,0,"lucky.numbers.com","/8738789417178304429"
          "2021-12-31",1,1,1,0,"lucky.numbers.com","/7445073500314667742"
          "2021-12-31",1,1,1,0,"lucky.numbers.com","/4897404798407749335"
          "2021-12-31",1,2,1,29,"lucky.numbers.com","/11263893625781431659"
          "2022-01-01",2,2,2,0,"lucky.numbers.com","/5878724061840196349"
          """
        },
        %{
          name: "imported_sources.csv",
          body: """
          "date","source","utm_medium","utm_campaign","utm_content","utm_term","visitors","visits","visit_duration","bounces"
          "2021-12-30","","","","","",25,26,254,24
          "2021-12-30","Hacker News","referral","","","",2,2,0,2
          "2021-12-30","Google","organic","","","",20,22,75,21
          "2021-12-30","Pinterest","referral","","","",25,26,0,26
          "2021-12-30","baidu","organic","","","",1,1,0,1
          "2021-12-30","yahoo","organic","","","",3,3,0,3
          "2021-12-31","","","","","",16,16,199,15
          "2021-12-31","Bing","organic","","","",1,1,0,1
          "2021-12-31","DuckDuckGo","organic","","","",1,1,0,1
          "2021-12-31","Hacker News","referral","","","",1,1,466,0
          "2021-12-31","Google","organic","","","",25,32,85,31
          "2021-12-31","Pinterest","referral","","","",22,24,88,22
          "2021-12-31","yahoo","organic","","","",3,3,1899,1
          "2022-01-01","","","","","",37,38,1137,35
          "2022-01-01","Bing","organic","","","",2,2,171,1
          "2022-01-01","DuckDuckGo","organic","","","",2,3,0,3
          "2022-01-01","Hacker News","referral","","","",1,1,0,1
          "2022-01-01","Google","referral","","","",1,1,0,1
          "2022-01-01","Google","organic","","","",21,23,115,19
          "2022-01-01","Pinterest","referral","","","",29,30,0,30
          "2022-01-01","yahoo","organic","","","",3,3,419,2
          "2022-01-06","","","","","",37,38,430,36
          "2022-01-06","Bing","organic","","","how lucky am I as UInt64",1,1,0,1
          "2022-01-06","Bing","organic","","","",3,3,10,2
          """
        },
        %{
          name: "imported_visitors.csv",
          body: """
          "date","visitors","pageviews","bounces","visits","visit_duration"
          "2011-12-25",5,50,2,7,8640
          "2011-12-26",3,4,2,3,43
          "2011-12-27",3,6,2,4,2313
          "2011-12-28",6,30,4,8,2264
          "2011-12-29",4,8,5,6,136
          "2011-12-30",1,1,1,1,0
          """
        }
      ]

      on_exit(fn ->
        keys = Enum.map(csvs, fn csv -> "#{site.id}/#{csv.name}" end)
        s3.(ExAws.S3.delete_all_objects("imports", keys))
      end)

      uploads =
        for %{name: name, body: body} <- csvs do
          key = "#{site.id}/#{name}"
          s3.(ExAws.S3.put_object("imports", key, body))
          %{"filename" => name, "s3_url" => s3_url(minio, "imports", key)}
        end

      {:ok, job} =
        CSVImporter.new_import(
          site,
          user,
          # to satisfy the non null constraints on the table I'm providing "0" dates (according to ClickHouse)
          start_date: ~D[1970-01-01],
          end_date: ~D[1970-01-01],
          uploads: uploads
        )

      job = Repo.reload!(job)

      assert :ok = Plausible.Workers.ImportAnalytics.perform(job)

      # on successfull import the start and end dates are updated
      assert %SiteImport{
               start_date: ~D[2011-12-25],
               end_date: ~D[2022-01-06],
               source: :csv,
               status: :completed
             } = Repo.get_by!(SiteImport, site_id: site.id)

      assert Plausible.Stats.Clickhouse.imported_pageview_count(site) == 99
    end

    test "fails on invalid CSV", %{site: site, user: user, s3: s3, container: minio} do
      csvs = [
        %{
          name: "imported_browsers.csv",
          body: """
          "date","browser","visitors","visits","visit_duration","bounces"
          "2021-12-30","Amazon Silk",2,2,0,2
          "2021-12-30","Chrome",31,32,329,29
          "2021-12-30","Edge",3,3,0,3
          "2021-12-30","Firefox",1,1,0,1
          "2021-12-30","Internet Explorer",1,1,0,1
          "2021-12-30","Mobile App",2,2,0,2
          "2021-12-31","Mobile App",4,4,0,4
          """
        },
        %{
          name: "imported_devices.csv",
          body: """
          "date","device","visitors","visit_duration","bounces"
          "2021-12-30","Desktop",28,ehhhh....
          """
        }
      ]

      on_exit(fn ->
        keys = Enum.map(csvs, fn csv -> "#{site.id}/#{csv.name}" end)
        s3.(ExAws.S3.delete_all_objects("imports", keys))
      end)

      uploads =
        for %{name: name, body: body} <- csvs do
          key = "#{site.id}/#{name}"
          s3.(ExAws.S3.put_object("imports", key, body))
          %{"filename" => name, "s3_url" => s3_url(minio, "imports", key)}
        end

      {:ok, job} =
        CSVImporter.new_import(
          site,
          user,
          start_date: ~D[1970-01-01],
          end_date: ~D[1970-01-01],
          uploads: uploads
        )

      job = Repo.reload!(job)

      assert {:discard, message} = Plausible.Workers.ImportAnalytics.perform(job)
      assert message =~ "CANNOT_PARSE_INPUT_ASSERTION_FAILED"

      assert %SiteImport{id: import_id, source: :csv, status: :failed} =
               Repo.get_by!(SiteImport, site_id: site.id)

      # ensure no browser left behind
      imported_browsers_q = from b in "imported_browsers", where: b.import_id == ^import_id
      assert await_clickhouse_count(imported_browsers_q, 0)
    end
  end

  describe "export -> import" do
    setup [:create_user, :create_new_site]

    setup do
      tmp_dir =
        Path.join(
          System.tmp_dir!(),
          "plausible-csv-importer-test-#{inspect(self())}-#{System.system_time(:millisecond)}"
        )

      File.mkdir!(tmp_dir)
      on_exit(fn -> File.rmdir!(tmp_dir) end)
      tmp_path = fn path -> Path.join(tmp_dir, path) end

      {:ok, tmp_path: tmp_path}
    end

    test "it works", %{site: site, user: user, s3: s3, tmp_path: tmp_path, container: minio} do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          pathname: "/",
          timestamp:
            Timex.shift(~N[2021-10-20 12:00:00], minutes: -1) |> NaiveDateTime.truncate(:second),
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409,
          referrer_source: "Google"
        ),
        build(:pageview,
          user_id: 123,
          pathname: "/some-other-page",
          timestamp:
            Timex.shift(~N[2021-10-20 12:00:00], minutes: -2) |> NaiveDateTime.truncate(:second),
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409,
          referrer_source: "Google"
        ),
        build(:pageview,
          pathname: "/",
          timestamp:
            Timex.shift(~N[2021-10-20 12:00:00], days: -1) |> NaiveDateTime.truncate(:second),
          utm_medium: "search",
          utm_campaign: "ads",
          utm_source: "google",
          utm_content: "content",
          utm_term: "term",
          browser: "Firefox",
          browser_version: "120",
          operating_system: "Mac",
          operating_system_version: "14"
        ),
        build(:pageview,
          timestamp:
            Timex.shift(~N[2021-10-20 12:00:00], months: -1) |> NaiveDateTime.truncate(:second),
          country_code: "EE",
          browser: "Firefox",
          browser_version: "120",
          operating_system: "Mac",
          operating_system_version: "14"
        ),
        build(:pageview,
          timestamp:
            Timex.shift(~N[2021-10-20 12:00:00], months: -5) |> NaiveDateTime.truncate(:second),
          utm_campaign: "ads",
          country_code: "EE",
          referrer_source: "Google",
          browser: "FirefoxNoVersion",
          operating_system: "MacNoVersion"
        ),
        build(:event,
          timestamp:
            Timex.shift(~N[2021-10-20 12:00:00], days: -1) |> NaiveDateTime.truncate(:second),
          name: "Signup",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        )
      ])

      # export archive to s3
      s3.(ExAws.S3.put_bucket("exports", "us-east-1"))
      on_exit(fn -> s3.(ExAws.S3.delete_bucket("exports")) end)

      Oban.insert!(
        Plausible.Workers.ExportCSV.new(%{
          "site_id" => site.id,
          "email_to" => user.email,
          "s3_bucket" => "exports",
          "s3_path" => "#{site.id}/Plausible.zip",
          "s3_config_overrides" => Map.new(MinioContainer.connection_opts(minio))
        })
      )

      on_exit(fn -> s3.(ExAws.S3.delete_object("exports", "#{site.id}/Plausible.zip")) end)
      assert %{success: 1} = Oban.drain_queue(queue: :s3_csv_export, with_safety: false)

      # download archive
      on_exit(fn -> File.rm(tmp_path.("Plausible.zip")) end)

      s3.(
        ExAws.S3.download_file(
          "exports",
          "/#{site.id}/Plausible.zip",
          tmp_path.("Plausible.zip")
        )
      )

      # unzip archive
      {:ok, files} = :zip.unzip(to_charlist(tmp_path.("Plausible.zip")), cwd: tmp_path.("/"))
      on_exit(fn -> Enum.each(files, &File.rm!/1) end)

      # upload csvs
      on_exit(fn ->
        keys = Enum.map(files, fn file -> "#{site.id}/#{Path.basename(file)}" end)
        s3.(ExAws.S3.delete_all_objects("imports", keys))
      end)

      uploads =
        Enum.map(files, fn file ->
          key = "#{site.id}/#{Path.basename(file)}"
          s3.(ExAws.S3.put_object("imports", key, File.read!(file)))
          %{"filename" => Path.basename(file), "s3_url" => s3_url(minio, "imports", key)}
        end)

      # run importer
      {:ok, job} =
        CSVImporter.new_import(
          site,
          user,
          start_date: ~D[1970-01-01],
          end_date: ~D[1970-01-01],
          uploads: uploads
        )

      job = Repo.reload!(job)

      assert :ok = Plausible.Workers.ImportAnalytics.perform(job)

      # validate import
      assert %SiteImport{
               start_date: ~D[2021-05-20],
               end_date: ~D[2021-10-20],
               source: :csv,
               status: :completed
             } = Repo.get_by!(SiteImport, site_id: site.id)

      assert Plausible.Stats.Clickhouse.imported_pageview_count(site) == 5
    end
  end

  defp s3_url(minio, bucket, key) do
    port = minio |> MinioContainer.connection_opts() |> Keyword.fetch!(:port)
    Path.join(["http://172.17.0.1:#{port}", bucket, key])
  end
end
