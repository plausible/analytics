defmodule Plausible.Imports.S3 do
  use Oban.Worker, queue: :s3_data_import

  @impl true
  def perform(job) do
    %Oban.Job{
      args: %{
        "site_id" => site_id,
        "email_to" => email,
        "uploads" => uploads
      }
    } = job

    site = Plausible.Repo.get!(Plausible.Site, site_id)

    %{access_key_id: s3_access_key_id, secret_access_key: s3_secret_access_key} =
      Plausible.S3.import_clickhouse_credentials()

    {:ok, ch} =
      Plausible.IngestRepo.config()
      |> Keyword.replace!(:pool_size, 1)
      |> Ch.start_link()

    Enum.each(uploads, fn upload ->
      %{"filename" => filename, "s3_path" => s3_path} = upload

      ".csv" = Path.extname(filename)
      table = Path.rootname(filename)

      s3_structure = Plausible.Imports.input_structure(table)
      s3_url = Plausible.S3.import_clickhouse_url(s3_path)

      statement =
        """
        INSERT INTO {table:Identifier} \
        SELECT {site_id:UInt64} AS site_id, * \
        FROM s3({s3_url:String},{s3_access_key_id:String},{s3_secret_access_key:String},{s3_format:String},{s3_structure:String})\
        """

      params = %{
        "table" => table,
        "site_id" => site_id,
        "s3_url" => s3_url,
        "s3_access_key_id" => s3_access_key_id,
        "s3_secret_access_key" => s3_secret_access_key,
        "s3_format" => "CSVWithNames",
        "s3_structure" => s3_structure
      }

      Ch.query!(ch, statement, params, timeout: :infinity)
    end)

    Plausible.Repo.transaction(fn ->
      site =
        site
        # TODO get min date for imported data (min part?)
        |> Plausible.Site.start_import(~D[0001-01-01], ~D[2030-01-01], "CSV imports")
        |> Plausible.Repo.update!()

      site
      |> Plausible.Site.import_success()
      |> Plausible.Repo.update!()
    end)

    Plausible.Mailer.deliver_now!(
      Bamboo.Email.new_email(
        from: "plausible@email.com",
        to: email,
        subject: "IMPORT SUCCESS",
        text_body: "IMPORT FOR SITE #{site_id} COMPLETE SUCCESS"
      )
    )

    :ok
  end
end
