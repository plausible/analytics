defmodule Plausible.S3 do
  @moduledoc """
  Helper functions for S3 exports/imports.
  """

  defp config, do: Application.fetch_env!(:plausible, __MODULE__)
  defp config(key), do: Keyword.fetch!(config(), key)

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

  In the current implementation the bucket goes into the path component:

      ${S3_ENDPOINT}/${S3_IMPORTS_BUCKET}/${S3_PATH}

      https://s3.us-east-1.amazonaws.com/my-plausible-imports/1/imported_browsers.csv

  """
  @spec import_clickhouse_url(Path.t()) :: :uri_string.uri_string()
  def import_clickhouse_url(s3_path) do
    %{scheme: scheme, host: host} = config = ExAws.Config.new(:s3)
    host = Keyword.get(config(), :host_for_clickhouse) || host
    port = ExAws.S3.Utils.sanitized_port_component(config)
    Path.join(["#{scheme}#{host}#{port}", config(:imports_bucket), s3_path])
  end
end
