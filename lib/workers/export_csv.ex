defmodule Plausible.Workers.ExportCSV do
  @moduledoc """
  Worker for running CSV export jobs.
  Supports S3 and local storage.
  """

  use Oban.Worker,
    queue: :csv_export,
    max_attempts: 3

  alias Plausible.Exports

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{
      "storage" => storage,
      "site_id" => site_id,
      "start_date" => start_date,
      "end_date" => end_date
    } = args

    start_date = Date.from_iso8601!(start_date)
    end_date = Date.from_iso8601!(end_date)

    queries =
      Exports.export_queries(site_id,
        date_range: Date.range(start_date, end_date),
        extname: ".csv"
      )

    # since each `perform` attempt runs in a separate process
    # it's ok to use start_link to keep connection lifecycle
    # bound to that of the worker
    {:ok, ch} =
      Plausible.ClickhouseRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    case storage do
      "s3" -> perform_s3_export(ch, queries, args)
      "local" -> perform_local_export(ch, queries, args)
    end

    :ok
  end

  defp perform_s3_export(ch, queries, args) do
    %{
      "s3_bucket" => s3_bucket,
      "s3_path" => s3_path
    } = args

    s3_config_overrides = s3_config_overrides(args)

    DBConnection.run(
      ch,
      fn conn ->
        conn
        |> Exports.stream_archive(queries, format: "CSVWithNames")
        |> Plausible.S3.export_upload_multipart(s3_bucket, s3_path, s3_config_overrides)
      end,
      timeout: :infinity
    )
  end

  # right now custom config is used in tests only (to access the minio container)
  # ideally it would be passed via the s3 url
  # but ExAws.S3.upload is hard to make work with s3 urls
  if Mix.env() in [:test, :small_test] do
    defp s3_config_overrides(args) do
      if config_overrides = args["s3_config_overrides"] do
        Enum.map(config_overrides, fn {k, v} -> {String.to_existing_atom(k), v} end)
      else
        []
      end
    end
  else
    defp s3_config_overrides(_args), do: []
  end

  def perform_local_export(ch, queries, args) do
    %{"local_path" => local_path} = args
    tmp_path = Plug.Upload.random_file!("tmp-plausible-export")

    DBConnection.run(
      ch,
      fn conn ->
        Exports.stream_archive(conn, queries, format: "CSVWithNames")
        |> Stream.into(File.stream!(tmp_path))
        |> Stream.run()
      end,
      timeout: :infinity
    )

    File.mkdir_p!(Path.dirname(local_path))
    if File.exists?(local_path), do: File.rm!(local_path)
    File.rename!(tmp_path, local_path)
  end
end
