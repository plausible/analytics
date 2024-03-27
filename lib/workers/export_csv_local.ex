defmodule Plausible.Workers.ExportCSVLocal do
  @moduledoc """
  Worker for running local CSV export jobs.
  """

  # TODO unify with ExportCSV (same queue, same worker, different args, especially "storage" => "s3" or "local")

  use Oban.Worker,
    queue: :local_csv_export,
    max_attempts: 3

  alias Plausible.Exports

  @impl true
  def perform(job) do
    %Oban.Job{
      args: %{
        "site_id" => site_id,
        "email_to" => email,
        "local_path" => local_path,
        "start_date" => start_date,
        "end_date" => end_date
      }
    } = job

    start_date = Date.from_iso8601!(start_date)
    end_date = Date.from_iso8601!(end_date)

    {:ok, ch} =
      Plausible.ClickhouseRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    perform_export(ch, site_id, Date.range(start_date, end_date), local_path, email)
  after
    Exports.oban_notify()
  end

  defp perform_export(ch, site_id, date_range, local_path, email) do
    domain = Plausible.Sites.get_domain!(site_id)

    export_queries =
      Exports.export_queries(site_id,
        date_range: date_range,
        extname: ".csv"
      )

    tmp_path = Plug.Upload.random_file!("tmp-plausible-export")

    DBConnection.run(
      ch,
      fn ch ->
        ch
        |> Exports.stream_archive(export_queries, format: "CSVWithNames")
        |> Stream.into(File.stream!(tmp_path))
        |> Stream.run()
      end,
      timeout: :infinity
    )

    File.mkdir_p!(Path.dirname(local_path))

    if File.exists?(local_path), do: File.rm!(local_path)
    File.rename!(tmp_path, local_path)

    download_url =
      PlausibleWeb.Router.Helpers.site_path(
        PlausibleWeb.Endpoint,
        :download_local_export,
        domain,
        Path.basename(local_path)
      )

    settings_url =
      PlausibleWeb.Router.Helpers.site_path(
        PlausibleWeb.Endpoint,
        :settings_imports_exports,
        domain
      )

    # NOTE: replace with proper Plausible.Email template
    Plausible.Mailer.deliver_now!(
      Bamboo.Email.new_email(
        from: PlausibleWeb.Email.mailer_email_from(),
        to: email,
        subject: "EXPORT SUCCESS",
        text_body: """
        download it from #{download_url} or manage it on #{settings_url}!
        """,
        html_body: """
        download it from <a href="#{download_url}">here</a> or manage it <a href="#{settings_url}">in the settings!</a>
        """
      )
    )

    :ok
  end
end
