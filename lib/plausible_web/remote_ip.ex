defmodule PlausibleWeb.RemoteIp do
  def get(conn) do
    cf_connecting_ip = List.first(Plug.Conn.get_req_header(conn, "cf-connecting-ip"))
    forwarded_for = List.first(Plug.Conn.get_req_header(conn, "x-forwarded-for"))

    cond do
      cf_connecting_ip ->
        cf_connecting_ip

      forwarded_for ->
        String.split(forwarded_for, ",")
        |> Enum.map(&String.trim/1)
        |> List.first()

      true ->
        to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end
end
