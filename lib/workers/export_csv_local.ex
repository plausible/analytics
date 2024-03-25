defmodule Plausible.Workers.ExportCSVLocal do
  @moduledoc """
  Worker for running local CSV export jobs.
  """

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
        "local_path" => local_path
      }
    } = job

    {:ok, ch} =
      Plausible.ClickhouseRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    [min_date, max_date] = min_max_dates(ch, site_id)

    if max_date == ~D[1970-01-01] do
      nothing_to_export(email)
    else
      perform_export(ch, site_id, Date.range(min_date, max_date), local_path, email)
    end
  after
    Exports.oban_notify()
  end

  defp min_max_dates(ch, site_id) do
    %Ch.Result{rows: [[%Date{}, %Date{}] = min_max_dates]} =
      Ch.query!(
        ch,
        "SELECT toDate(min(timestamp)), toDate(max(timestamp)) FROM events_v2 WHERE site_id={site_id:UInt64}",
        %{"site_id" => site_id}
      )

    min_max_dates
  end

  defp nothing_to_export(email) do
    # NOTE: replace with proper Plausible.Email template
    Plausible.Mailer.deliver_now!(
      Bamboo.Email.new_email(
        from: PlausibleWeb.Email.mailer_email_from(),
        to: email,
        subject: "EXPORT FAILURE",
        text_body: "there is nothing to export"
      )
    )

    {:cancel, "there is nothing to export"}
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
