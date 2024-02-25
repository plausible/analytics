defmodule Plausible.Workers.ExportCSV do
  @moduledoc """
  Worker for running CSV export jobs.
  """

  use Oban.Worker,
    queue: :s3_csv_export,
    max_attempts: 3,
    unique: [fields: [:args], keys: [:s3_path], period: 60]

  @impl true
  def perform(job) do
    %Oban.Job{
      args: %{
        "site_id" => site_id,
        "email_to" => email,
        "s3_path" => s3_path
      }
    } = job

    {:ok, ch} =
      Plausible.ClickhouseRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    download_url =
      DBConnection.run(
        ch,
        fn conn ->
          conn
          |> Plausible.Exports.stream_archive(
            Plausible.Exports.export_queries(site_id, extname: ".csv"),
            format: "CSVWithNames"
          )
          |> Plausible.S3.export_upload_multipart(s3_path)
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

    :ok
  end
end
