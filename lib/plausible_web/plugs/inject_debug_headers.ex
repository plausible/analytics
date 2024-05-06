defmodule PlausibleWeb.Plugs.InjectDebugHeaders do
  @moduledoc """
  This plug updates the response with debug query headers,
  granted they were tracked via `Plausible.DebugReplayInfo`.
  """

  @max_header_size 8000

  def init(opts), do: opts

  def call(conn, _opts \\ []) do
    Plug.Conn.register_before_send(conn, fn conn ->
      Plausible.DebugReplayInfo.get_queries_from_context()
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.reduce(conn, fn {q, index}, conn ->
        {[label], [value]} = Enum.unzip(q)

        {label, value} = sanitize(label, value, index)

        Plug.Conn.put_resp_header(conn, label, String.replace(value, ["\n", "\r", "\x00"], ""))
      end)
    end)
  end

  defp sanitize(label, value, index) when byte_size(value) > @max_header_size do
    {"#{annotate(label, index)}-cropped", String.slice(value, 0, @max_header_size)}
  end

  defp sanitize(label, value, index) do
    {"#{annotate(label, index)}", value}
  end

  defp annotate(label, index),
    do: "x-plausible-query-#{String.pad_leading("#{index}", 3, "0")}-#{label}"
end
