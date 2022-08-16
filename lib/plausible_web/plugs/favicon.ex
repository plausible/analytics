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

        case HTTPClient.get("https://icons.duckduckgo.com/ip3/#{domain}") do
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
    conn =
      Enum.filter(res.headers, fn {key, _val} -> key != "Transfer-Encoding" end)
      |> Enum.reduce(conn, fn {key, val}, conn ->
        put_resp_header(conn, key, val)
      end)

    send_resp(conn, 200, res.body) |> halt
  end
end
