defmodule Plausible.Workers.ExportAnalytics do
  @moduledoc """
  Worker for running CSV export jobs. Supports S3 and local storage.
  To avoid blocking the queue, a timeout of 15 minutes is enforced.
  """

  use Oban.Worker,
    queue: :analytics_exports,
    max_attempts: 3

  alias Plausible.Exports

  @doc "This base query filters export jobs for a site"
  def base_query(site_id) do
    import Ecto.Query, only: [from: 2]

    from j in Oban.Job,
      where: j.worker == ^Oban.Worker.to_string(__MODULE__),
      where: j.args["site_id"] == ^site_id
  end

  @impl true
  def timeout(_job), do: :timer.minutes(15)

  @impl true
  def perform(%Oban.Job{args: args} = job) do
    %{
      "storage" => storage,
      "site_id" => site_id
    } = args

    current_user_id = args["current_user_id"]

    site = Plausible.Repo.get!(Plausible.Site, site_id)
    %Date.Range{} = date_range = Exports.date_range(site.id, site.timezone)

    queries =
      Exports.export_queries(site_id, current_user_id,
        date_range: date_range,
        timezone: site.timezone,
        extname: ".csv"
      )

    # since each worker / `perform` attempt runs in a separate process
    # it's ok to use start_link to keep connection lifecycle
    # bound to that of the worker
    {:ok, ch} =
      Plausible.ClickhouseRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    try do
      case storage do
        "s3" -> perform_s3_export(ch, site, queries, args)
        "local" -> perform_local_export(ch, queries, args)
      end
    after
      Exports.oban_notify(site_id)
    end

    email_success(job.args)

    :ok
  catch
    class, reason ->
      if job.attempt >= job.max_attempts, do: email_failure(job.args)
      :erlang.raise(class, reason, __STACKTRACE__)
  end

  defp perform_s3_export(ch, site, queries, args) do
    %{
      "s3_bucket" => s3_bucket,
      "s3_path" => s3_path
    } = args

    created_on = Plausible.Timezones.to_date_in_timezone(DateTime.utc_now(), site.timezone)
    filename = Exports.archive_filename(site.domain, created_on)

    DBConnection.run(
      ch,
      fn conn ->
        conn
        |> Exports.stream_archive(queries, format: "CSVWithNames")
        |> Plausible.S3.export_upload_multipart(s3_bucket, s3_path, filename)
      end,
      timeout: :infinity
    )
  end

  defp perform_local_export(ch, queries, args) do
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
    Plausible.File.mv!(tmp_path, local_path)
  end

  defp email_failure(args) do
    args |> Map.put("status", "failure") |> email()
  end

  defp email_success(args) do
    args |> Map.put("status", "success") |> email()
  end

  defp email(args) do
    # email delivery can potentially fail and cause already successful
    # export to be repeated which is costly, hence email is delivered
    # in a separate job
    Oban.insert!(Plausible.Workers.NotifyExportedAnalytics.new(args))
  end
end
