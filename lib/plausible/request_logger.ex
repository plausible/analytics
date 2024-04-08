defmodule Plausible.RequestLogger do
  @moduledoc """
  Custom request logger which:
  - Includes query parameters on the same line
  - Includes request duration on the same line
  """

  require Logger

  def log_request(_, %{duration: duration}, %{conn: conn}, _) do
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)
    path = path_with_params(conn.request_path, conn.query_string)

    Logger.info("(#{conn.status}) #{conn.method} #{path} took #{duration_ms}ms")
  end

  defp path_with_params(request_path, ""), do: request_path
  defp path_with_params(request_path, query_string), do: request_path <> "?" <> query_string
end
