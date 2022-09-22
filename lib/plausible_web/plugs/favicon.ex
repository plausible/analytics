defmodule PlausibleWeb.Favicon do
  import Plug.Conn
  alias Plausible.HTTPClient

  def init(_) do
    domains =
      case File.read(Application.app_dir(:plausible, "priv/referer_favicon_domains.json")) do
        {:ok, contents} ->
          Jason.decode!(contents)

        _ ->
          %{}
      end

    [favicon_domains: domains]
  end

  def call(conn, favicon_domains: favicon_domains) do
    case conn.path_info do
      ["favicon", "sources", source] ->
        clean_source = URI.decode_www_form(source)
        domain = Map.get(favicon_domains, clean_source, clean_source)

        case HTTPClient.impl().get("https://icons.duckduckgo.com/ip3/#{domain}.ico") do
          {:ok, res} ->
            send_response(conn, res)

          _ ->
            send_resp(conn, 503, "") |> halt
        end

      _ ->
        conn
    end
  end

  defp send_response(conn, res) do
    headers = remove_hop_by_hop_headers(res)
    conn = %Plug.Conn{conn | resp_headers: headers}

    send_resp(conn, 200, res.body) |> halt
  end

  @hop_by_hop_headers [
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade"
  ]
  defp remove_hop_by_hop_headers(%Finch.Response{headers: headers}) do
    Enum.filter(headers, fn {key, _} -> key not in @hop_by_hop_headers end)
  end
end
