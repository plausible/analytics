defmodule Plausible.Workers.ExportCSV do
  @moduledoc """
  Worker for running CSV export jobs.
  """

  use Oban.Worker,
    queue: :s3_csv_export,
    max_attempts: 3,
    unique: [fields: [:args], keys: [:s3_bucket, :s3_path], period: 60]

  @impl true
  def perform(job) do
    %Oban.Job{
      args:
        %{
          "site_id" => site_id,
          "email_to" => email,
          "s3_bucket" => s3_bucket,
          "s3_path" => s3_path
        } = args
    } = job

    {:ok, ch} =
      Plausible.ClickhouseRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    %Ch.Result{rows: [[min_date, max_date]]} =
      Ch.query!(
        ch,
        "SELECT toDate(min(timestamp)), toDate(max(timestamp)) FROM events_v2 WHERE site_id={site_id:UInt64}",
        %{"site_id" => site_id}
      )

    if max_date == ~D[1970-01-01] do
      # NOTE: replace with proper Plausible.Email template
      Plausible.Mailer.deliver_now!(
        Bamboo.Email.new_email(
          from: "plausible@email.com",
          to: email,
          subject: "EXPORT FAILURE",
          text_body: "there is nothing to export"
        )
      )
    else
      download_url =
        DBConnection.run(
          ch,
          fn conn ->
            conn
            |> Plausible.Exports.stream_archive(
              Plausible.Exports.export_queries(site_id,
                date_range: Date.range(min_date, max_date),
                extname: ".csv"
              ),
              format: "CSVWithNames"
            )
            |> Plausible.S3.export_upload_multipart(s3_bucket, s3_path, s3_config_overrides(args))
          end,
          timeout: :infinity
        )

      # NOTE: replace with proper Plausible.Email template
      Plausible.Mailer.deliver_now!(
        Bamboo.Email.new_email(
          from: "plausible@email.com",
          to: email,
          subject: "EXPORT SUCCESS",
          text_body: """
          download it from #{download_url}! hurry up! you have 24 hours!"
          """,
          html_body: """
          download it from <a href="#{download_url}">here</a>! hurry up! you have 24 hours!
          """
        )
      )
    end

    :ok
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
end
