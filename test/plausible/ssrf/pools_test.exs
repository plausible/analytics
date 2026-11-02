defmodule Plausible.SSRF.PoolsTest do
  use ExUnit.Case, async: true

  alias Plausible.SSRF.Pools
  alias Plausible.Test.Support.TLSServer

  @host "good.example"

  setup do
    {ca, port} =
      TLSServer.start(
        cert_host: @host,
        handler: fn conn, _port -> Plug.Conn.send_resp(conn, 200, "ok") end
      )

    {:ok, ca: ca, port: port, url: URI.parse("https://127.0.0.1:#{port}/"), ip: {127, 0, 0, 1}}
  end

  defp with_pool(ctx, host, fun) do
    Pools.with_pool(ctx.url, host, ctx.ip, [ctx.ca], fun)
  end

  defp request(ctx, host, finch) do
    Req.request(method: :get, url: ctx.url, headers: [{"host", host}], finch: finch, retry: false)
  end

  # Checking the pid rather than looking the pool up again: a stopped pool
  # lingers in Finch's registry for a moment.
  defp pool_pid!(ctx, finch) do
    pool = %Finch.Pool{
      scheme: :https,
      host: "127.0.0.1",
      port: ctx.url.port,
      tag: finch[:pool_tag]
    }

    assert {:ok, pid} = Finch.find_pool(Pools.Finch, pool)
    pid
  end

  test "carries the request to the pinned address under a pool of its own", ctx do
    result = with_pool(ctx, @host, fn finch -> request(ctx, @host, finch) end)

    assert {:ok, %Req.Response{status: 200, body: "ok"}} = result
  end

  test "the pool lives for the request and is stopped once it returns", ctx do
    pid =
      with_pool(ctx, @host, fn finch ->
        pid = pool_pid!(ctx, finch)
        assert {:ok, %Req.Response{status: 200}} = request(ctx, @host, finch)
        pid
      end)

    refute Process.alive?(pid)
  end

  test "the pool is stopped even when the connection was refused", ctx do
    # Finch's idle reaping never sees a pool whose only connection was refused.
    ctx = %{ctx | url: URI.parse("https://127.0.0.1:#{closed_port()}/")}

    {result, pid} =
      with_pool(ctx, "dead.example", fn finch ->
        {request(ctx, "dead.example", finch), pool_pid!(ctx, finch)}
      end)

    assert {:error, %Req.TransportError{reason: :econnrefused}} = result
    refute Process.alive?(pid)
  end

  test "the pool is stopped even when the request raises", ctx do
    test_pid = self()

    assert_raise RuntimeError, "boom", fn ->
      with_pool(ctx, @host, fn finch ->
        send(test_pid, {:pool, pool_pid!(ctx, finch)})
        raise "boom"
      end)
    end

    assert_receive {:pool, pid}
    refute Process.alive?(pid)
  end

  @tag :capture_log
  test "the pool is stopped when the caller is killed without warning", ctx do
    # `after` doesn't run on :kill, which is how a cancelled Oban job ends.
    test_pid = self()

    caller =
      spawn(fn ->
        with_pool(ctx, @host, fn finch ->
          send(test_pid, {:pool, pool_pid!(ctx, finch)})
          Process.sleep(:infinity)
        end)
      end)

    assert_receive {:pool, pid}
    ref = Process.monitor(pid)

    Process.exit(caller, :kill)

    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 1_000
  end

  test "concurrent requests to one hostname each get a pool of their own", ctx do
    pids =
      1..5
      |> Task.async_stream(fn _ ->
        with_pool(ctx, @host, fn finch ->
          pid = pool_pid!(ctx, finch)
          assert {:ok, %Req.Response{status: 200}} = request(ctx, @host, finch)
          pid
        end)
      end)
      |> Enum.map(fn {:ok, pid} -> pid end)

    assert length(Enum.uniq(pids)) == 5
    refute Enum.any?(pids, &Process.alive?/1)
  end

  defp closed_port do
    {:ok, socket} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end
end
