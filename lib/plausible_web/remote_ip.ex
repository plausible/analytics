defmodule PlausibleWeb.RemoteIP do
  @moduledoc """
  Implements the strategy of retrieving client's remote IP
  """

  def get(conn) do
    x_plausible_ip = List.first(Plug.Conn.get_req_header(conn, "x-plausible-ip")) || ""
    cf_connecting_ip = List.first(Plug.Conn.get_req_header(conn, "cf-connecting-ip")) || ""
    x_forwarded_for = List.first(Plug.Conn.get_req_header(conn, "x-forwarded-for")) || ""
    b_forwarded_for = List.first(Plug.Conn.get_req_header(conn, "b-forwarded-for")) || ""
    forwarded = List.first(Plug.Conn.get_req_header(conn, "forwarded")) || ""

    cond do
      byte_size(x_plausible_ip) > 0 ->
        clean_ip(x_plausible_ip)

      byte_size(cf_connecting_ip) > 0 ->
        clean_ip(cf_connecting_ip)

      byte_size(b_forwarded_for) > 0 ->
        parse_forwarded_for(b_forwarded_for)

      byte_size(x_forwarded_for) > 0 ->
        parse_forwarded_for(x_forwarded_for)

      byte_size(forwarded) > 0 ->
        Regex.named_captures(~r/for=(?<for>[^;,]+).*$/, forwarded)
        |> Map.get("for")
        # IPv6 addresses are enclosed in quote marks and square brackets: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Forwarded
        |> String.trim("\"")
        |> clean_ip()

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

  defp parse_forwarded_for(header) do
    String.split(header, ",")
    |> Enum.map(&String.trim/1)
    |> List.first()
    |> clean_ip()
  end
end
