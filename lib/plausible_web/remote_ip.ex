defmodule PlausibleWeb.RemoteIp do
  def get(conn) do
    cf_connecting_ip = List.first(Plug.Conn.get_req_header(conn, "cf-connecting-ip"))
    forwarded_for = List.first(Plug.Conn.get_req_header(conn, "x-forwarded-for"))
    forwarded = List.first(Plug.Conn.get_req_header(conn, "forwarded"))

    cond do
      cf_connecting_ip ->
        cf_connecting_ip
        |> clean_ip

      forwarded_for ->
        String.split(forwarded_for, ",")
        |> Enum.map(&String.trim/1)
        |> List.first()
        |> clean_ip

      forwarded ->
        Regex.named_captures(~r/for=(?<for>[^;,]+).*$/, forwarded)
        |> Map.get("for")
        # IPv6 addresses are enclosed in quote marks and square brackets: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Forwarded
        |> String.trim("\"")
        |> clean_ip

      true ->
        to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end

  # Removes port from both IPv4 and IPv6 addresses. From https://regexr.com/3hpvt
  # Removes surrounding [] of an IPv6 address
  @port_regex ~r/((\.\d+)|(\]))(?<port>:[0-9]+)$/
  defp clean_ip(ip_and_port) do
    ip =
      case Regex.named_captures(@port_regex, ip_and_port) do
        %{"port" => port} -> String.trim_trailing(ip_and_port, port)
        _ -> ip_and_port
      end

    ip
    |> String.trim_leading("[")
    |> String.trim_trailing("]")
  end
end
