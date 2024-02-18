defmodule Plausible.ExportsTest do
  use Plausible.DataCase

  describe "stream_archive/3" do
    test "build a valid uncompressed Zip archive for the provided queries" do
      tmp_path = tmp_touch("plausible_exports_stream_archive_test.zip")

      named_queries = %{
        "three.csv" =>
          from(n in fragment("numbers(3)"),
            select: [
              n.number,
              n.number + 1000
            ]
          ),
        "thousand.csv" =>
          from(n in fragment("numbers(1000)"),
            select: [
              n.number,
              selected_as(fragment("toString(?)", n.number), :not_number)
            ]
          )
      }

      DBConnection.run(ch(), fn conn ->
        conn
        |> Plausible.Exports.stream_archive(named_queries, format: "CSVWithNames")
        |> Stream.into(File.stream!(tmp_path))
        |> Stream.run()
      end)

      assert {:ok, files} = :zip.unzip(to_charlist(tmp_path), cwd: System.tmp_dir!())
      on_exit(fn -> Enum.each(files, &File.rm!/1) end)

      read_csv = fn name ->
        Enum.find(files, fn file -> Path.basename(file) == name end)
        |> File.read!()
        |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
      end

      assert read_csv.("three.csv") == [
               ["number", "plus(number, 1000)"],
               ["0", "1000"],
               ["1", "1001"],
               ["2", "1002"]
             ]

      assert [
               ["number", "not_number"],
               ["0", "0"],
               ["1", "1"],
               ["2", "2"],
               ["3", "3"] | rest
             ] = read_csv.("thousand.csv")

      assert length(rest) == 1000 - 4
    end

    test "raises in case of an error and halts the stream" do
      bad_queries = %{
        "invalid" => from(t in "bad_table", select: t.bad_column),
        "valid" => from(n in fragment("numbers(1)"), select: n.number)
      }

      assert_raise Ch.Error, ~r/UNKNOWN_TABLE/, fn ->
        DBConnection.run(ch(), fn conn ->
          conn
          |> Plausible.Exports.stream_archive(bad_queries)
          |> Stream.run()
        end)
      end
    end
  end

  defp ch do
    {:ok, conn} =
      Plausible.ClickhouseRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    conn
  end

  defp tmp_touch(name) do
    tmp_path = Path.join(System.tmp_dir!(), name)
    File.touch!(tmp_path)
    on_exit(fn -> File.rm!(tmp_path) end)
    tmp_path
  end
end
