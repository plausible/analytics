defmodule PlausibleWeb.RemoteIp do
  def get(conn) do
    cf_connecting_ip = List.first(Plug.Conn.get_req_header(conn, "cf-connecting-ip"))
    forwarded_for = List.first(Plug.Conn.get_req_header(conn, "x-forwarded-for"))
    forwarded = List.first(Plug.Conn.get_req_header(conn, "forwarded"))

    cond do
      cf_connecting_ip ->
        cf_connecting_ip

      forwarded_for ->
        String.split(forwarded_for, ",")
        |> Enum.map(&String.trim/1)
        |> List.first()
        |> remove_port

      forwarded ->
        Regex.named_captures(~r/for=(?<for>[^;,]+).*$/, forwarded)
        |> Map.get("for")
        # IPv6 addresses are enclosed in quote marks and square brackets: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Forwarded
        |> String.trim("\"")
        |> String.trim_leading("[")
        |> String.trim_trailing("]")

      true ->
        to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end

  defp remove_port(ip) do
    String.split(ip, ":")
    |> List.first()
  end
end
