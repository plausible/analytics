defmodule Plausible.SSRF.PoolsTest do
  use ExUnit.Case, async: true

  alias Plausible.SSRF.Pools
  alias Plausible.Test.Support.TLSServer

  @host "good.example"

  setup do
    {ca, port} =
      TLSServer.start(
        cert_host: [@host, "other.example"],
        handler: fn conn, _port -> Plug.Conn.send_resp(conn, 200, "ok") end
      )

    {:ok, ca: ca, url: URI.parse("https://127.0.0.1:#{port}/"), ip: {127, 0, 0, 1}}
  end

  defp request(ctx, host) do
    finch = Pools.finch_opts(ctx.url, host, ctx.ip, [ctx.ca])

    result =
      Req.request(
        method: :get,
        url: ctx.url,
        headers: [{"host", host}],
        finch: finch,
        retry: false
      )

    {result, pool_pid!(ctx, finch)}
  end

  defp pool_pid!(ctx, finch) do
    pool = %Finch.Pool{
      scheme: :https,
      host: ctx.url.host,
      port: ctx.url.port,
      tag: finch[:pool_tag]
    }

    assert {:ok, pid} = Finch.find_pool(Pools.Finch, pool)
    pid
  end

  test "carries the request to the pinned address", ctx do
    assert {{:ok, %Req.Response{status: 200, body: "ok"}}, _pid} = request(ctx, @host)
  end

  test "requests to one hostname share a pool", ctx do
    {{:ok, _}, pid} = request(ctx, @host)
    {{:ok, _}, ^pid} = request(ctx, @host)
  end

  test "hostnames on one address get pools of their own", ctx do
    {{:ok, _}, pid} = request(ctx, @host)
    {{:ok, _}, other_pid} = request(ctx, "other.example")

    assert pid != other_pid
  end

  test "an idle pool stops", ctx do
    {{:ok, _}, pid} = request(ctx, @host)
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 2_000
  end

  test "an idle pool stops even when its connection was refused", ctx do
    ctx = %{ctx | url: URI.parse("https://127.0.0.1:#{closed_port()}/")}

    {result, pid} = request(ctx, @host)
    ref = Process.monitor(pid)

    assert {:error, %Req.TransportError{reason: :econnrefused}} = result
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 2_000
  end

  defp closed_port do
    {:ok, socket} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end
end
