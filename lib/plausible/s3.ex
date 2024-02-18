defmodule Plausible.S3 do
  @moduledoc """
  Helper functions for S3 exports/imports.
  """

  defp config, do: Application.fetch_env!(:plausible, __MODULE__)
  defp config(key), do: Keyword.fetch!(config(), key)

  @doc """
  Chunks and uploads Zip archive to the pre-configured bucket.

  Returns a presigned URL to download the exported Zip archive from S3.
  The URL expires in 24 hours.

  In the current implementation the bucket always goes into the path component.
  """
  @spec export_upload_multipart(Enumerable.t(), Path.t()) :: :uri_string.uri_string()
  def export_upload_multipart(stream, s3_path) do
    config = ExAws.Config.new(:s3)
    bucket = config(:exports_bucket)

    stream
    |> chunk_into_parts(_5MiB = 5 * 1024 * 1024)
    |> ExAws.S3.upload(bucket, s3_path,
      content_disposition: ~s|attachment; filename="Plausible.zip"|,
      content_type: "application/zip"
    )
    |> ExAws.request!()

    {:ok, download_url} =
      ExAws.S3.presigned_url(config, :get, bucket, s3_path, expires_in: _24hr = 86400)

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
      # TODO PR to make ExAws.Operation.ExAws.Operation.S3.put_content_length_header/3 accept iodata
      {:cont, IO.iodata_to_binary(new_buffer), %{acc | buffer_size: 0, buffer: []}}
    else
      {:cont, %{acc | buffer_size: new_buffer_size, buffer: new_buffer}}
    end
  end

  defp flush_leftovers(acc) do
    # TODO PR to make ExAws.Operation.ExAws.Operation.S3.put_content_length_header/3 accept iodata
    {:cont, IO.iodata_to_binary(acc.buffer), %{acc | buffer_size: 0, buffer: []}}
  end

  @doc """
  Presigns an upload for an imported file.

  In the current implementation the bucket always goes into the path component.

  Example:

      import_presign_upload(_site_id = 123, _filename = "imported_browsers.csv")
      %{
        object: "123/imported_browsers.csv",
        url: "http://localhost:9000/imports/123/imported_browsers.csv?X"
      }

  """
  @spec import_presign_upload(pos_integer, String.t()) ::
          %{object: Path.t(), url: :uri_string.uri_string()}
  def import_presign_upload(site_id, filename) do
    config = ExAws.Config.new(:s3)
    s3_path = Path.join(to_string(site_id), filename)
    bucket = config(:imports_bucket)
    {:ok, upload_url} = ExAws.S3.presigned_url(config, :put, bucket, s3_path)
    %{object: s3_path, url: upload_url}
  end

  @doc """
  Returns `access_key_id` and `secret_access_key` to be used by ClickHouse during imports from S3.
  """
  @spec import_clickhouse_credentials ::
          %{access_key_id: String.t(), secret_access_key: String.t()}
  def import_clickhouse_credentials do
    %{access_key_id: access_key_id, secret_access_key: secret_access_key} = ExAws.Config.new(:s3)
    %{access_key_id: access_key_id, secret_access_key: secret_access_key}
  end

  @doc """
  Returns S3 URL for an object to be used by ClickHouse during imports from S3.

  In the current implementation the bucket always goes into the path component.
  """
  @spec import_clickhouse_url(Path.t()) :: :uri_string.uri_string()
  def import_clickhouse_url(s3_path) do
    %{scheme: scheme, host: host} = config = ExAws.Config.new(:s3)
    host = Keyword.get(config(), :host_for_clickhouse) || host
    port = ExAws.S3.Utils.sanitized_port_component(config)
    Path.join(["#{scheme}#{host}#{port}", config(:imports_bucket), s3_path])
  end
end
