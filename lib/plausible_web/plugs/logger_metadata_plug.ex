defmodule PlausibleWeb.LoggerMetadataPlug do
  require Logger

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    start = System.monotonic_time()

    Plug.Conn.register_before_send(conn, fn conn ->
      pipelines = conn.private[:phoenix_pipelines]
      controller = conn.private[:phoenix_controller] |> encode_controller()
      action = conn.private[:phoenix_action]
      method = conn.method
      path = conn.request_path
      url = "#{conn.scheme}://#{conn.host}:#{conn.port}#{path}"
      source = to_string(:inet.ntoa(conn.remote_ip))
      status = conn.status
      target = "plausible"
      params = filter_values(conn.params)

      stop = System.monotonic_time()
      diff = System.convert_time_unit(stop - start, :native, :microsecond)

      meta = [
        action: action,
        controller: controller,
        method: method,
        params: params,
        path: path,
        pipelines: pipelines,
        source: source,
        status: status,
        target: target,
        time_us: diff,
        url: url
      ]

      Logger.metadata(meta)

      conn
    end)
  end

  defp encode_controller(nil), do: nil

  defp encode_controller(atom) when is_atom(atom),
    do: atom |> Atom.to_string() |> encode_controller()

  defp encode_controller("Elixir." <> rest), do: rest
  defp encode_controller(controller), do: controller

  @filtered_keys ~w(email password password_confirmation)

  defp filter_values(%Plug.Conn.Unfetched{}), do: "[UNFETCHED]"
  defp filter_values(map) when is_map(map), do: Enum.into(map, %{}, &filter_values/1)
  defp filter_values(list) when is_list(list), do: Enum.map(list, &filter_values/1)

  defp filter_values({key, _value}) when key in @filtered_keys, do: {key, "[FILTERED]"}
  defp filter_values({key, value}), do: {key, value}
end
