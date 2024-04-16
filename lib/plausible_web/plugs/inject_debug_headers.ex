defmodule PlausibleWeb.Plugs.InjectDebugHeaders do
  @moduledoc """
  This plug updates the response with debug query headers,
  granted they were tracked via `Plausible.DebugReplayInfo`.
  """

  def init(opts), do: opts

  def call(conn, _opts \\ []) do
    Plug.Conn.register_before_send(conn, fn conn ->
      Plausible.DebugReplayInfo.get_queries_from_context()
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.reduce(conn, fn {q, index}, conn ->
        {[label], [value]} = Enum.unzip(q)

        conn
        |> Plug.Conn.put_resp_header(
          "x-plausible-query-#{String.pad_leading("#{index}", 3, "0")}-#{label}",
          String.replace(value, ["\n", "\r"], "")
        )
      end)
    end)
  end
end
