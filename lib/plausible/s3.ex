defmodule Plausible.S3 do
  @moduledoc """
  Helper functions for S3 exports/imports.
  """

  @doc """
  Returns the pre-configured S3 bucket for CSV exports.

      config :plausible, Plausible.S3,
        exports_bucket: System.fetch_env!("S3_EXPORTS_BUCKET")

  Example:

      iex> exports_bucket()
      "test-exports"

  """
  @spec exports_bucket :: String.t()
  def exports_bucket, do: config(:exports_bucket)

  @doc """
  Returns the pre-configured S3 bucket for CSV imports.

      config :plausible, Plausible.S3,
        imports_bucket: System.fetch_env!("S3_IMPORTS_BUCKET")

  Example:

      iex> imports_bucket()
      "test-imports"

  """
  @spec imports_bucket :: String.t()
  def imports_bucket, do: config(:imports_bucket)

  defp config, do: Application.fetch_env!(:plausible, __MODULE__)
  defp config(key), do: Keyword.fetch!(config(), key)

  @doc """
  Presigns an upload for an imported file.

  In the current implementation the bucket always goes into the path component.

  Example:

      iex> %{
      ...>   s3_url:  "http://localhost:10000/test-imports/123/imported_browsers.csv",
      ...>   presigned_url: "http://localhost:10000/test-imports/123/imported_browsers.csv?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=minioadmin" <> _
      ...> } = import_presign_upload(_site_id = 123, _filename = "imported_browsers.csv")

  """
  def import_presign_upload(site_id, filename) do
    config = ExAws.Config.new(:s3)
    s3_path = Path.join(Integer.to_string(site_id), filename)
    bucket = imports_bucket()
    {:ok, presigned_url} = ExAws.S3.presigned_url(config, :put, bucket, s3_path)
    %{s3_url: extract_s3_url(presigned_url), presigned_url: presigned_url}
  end

  # to make ClickHouse see MinIO in dev and test envs we replace
  # the host in the S3 URL with whatever's set in S3_CLICKHOUSE_HOST env var
  if Mix.env() in [:dev, :test, :small_dev, :small_test] do
    defp extract_s3_url(presigned_url) do
      [s3_url, _] = String.split(presigned_url, "?")

      if ch_host = System.get_env("S3_CLICKHOUSE_HOST") do
        URI.to_string(%URI{URI.parse(s3_url) | host: ch_host})
      else
        s3_url
      end
    end
  else
    defp extract_s3_url(presigned_url) do
      [s3_url, _] = String.split(presigned_url, "?")
      s3_url
    end
  end

  @doc """
  Chunks and uploads Zip archive to the provided S3 destination.

  In the current implementation the bucket always goes into the path component.
  """
  @spec export_upload_multipart(Enumerable.t(), String.t(), Path.t(), String.t(), keyword) ::
          :ok
  def export_upload_multipart(stream, s3_bucket, s3_path, filename, config_overrides \\ []) do
    # 5 MiB is the smallest chunk size AWS S3 supports
    chunk_into_parts(stream, 5 * 1024 * 1024)
    |> ExAws.S3.upload(s3_bucket, s3_path,
      content_disposition: Plausible.Exports.content_disposition(filename),
      content_type: "application/zip"
    )
    |> ExAws.request!(config_overrides)

    :ok
  end

  @doc """
  Returns a presigned URL to download the exported Zip archive from S3.
  The URL expires in 24 hours.

  In the current implementation the bucket always goes into the path component.
  """
  @spec export_download_url(String.t(), Path.t()) :: :uri_string.uri_string()
  def export_download_url(s3_bucket, s3_path) do
    config = ExAws.Config.new(:s3)

    {:ok, download_url} =
      ExAws.S3.presigned_url(config, :get, s3_bucket, s3_path, expires_in: _24hr = 86_400)

    download_url
  end

  defp chunk_into_parts(stream, min_part_size) do
    Stream.chunk_while(
      stream,
      _acc = %{buffer_size: 0, buffer: [], min_part_size: min_part_size},
      _chunk_fun = &buffer_until_big_enough/2,
      _after_fun = &flush_leftovers/1
    )
  end

  defp buffer_until_big_enough(data, acc) do
    %{buffer_size: prev_buffer_size, buffer: prev_buffer, min_part_size: min_part_size} = acc
    new_buffer_size = prev_buffer_size + IO.iodata_length(data)
    new_buffer = [prev_buffer | data]

    if new_buffer_size > min_part_size do
      # NOTE: PR to make ExAws.Operation.ExAws.Operation.S3.put_content_length_header/3 accept iodata
      {:cont, IO.iodata_to_binary(new_buffer), %{acc | buffer_size: 0, buffer: []}}
    else
      {:cont, %{acc | buffer_size: new_buffer_size, buffer: new_buffer}}
    end
  end

  defp flush_leftovers(acc) do
    # NOTE: PR to make ExAws.Operation.ExAws.Operation.S3.put_content_length_header/3 accept iodata
    {:cont, IO.iodata_to_binary(acc.buffer), %{acc | buffer_size: 0, buffer: []}}
  end

  @doc """
  Returns `access_key_id` and `secret_access_key` to be used by ClickHouse during imports from S3.

  Example:

      iex> import_clickhouse_credentials()
      %{access_key_id: "minioadmin", secret_access_key: "minioadmin"}

  """
  @spec import_clickhouse_credentials ::
          %{access_key_id: String.t(), secret_access_key: String.t()}
  def import_clickhouse_credentials do
    %{access_key_id: access_key_id, secret_access_key: secret_access_key} = ExAws.Config.new(:s3)
    %{access_key_id: access_key_id, secret_access_key: secret_access_key}
  end
end
