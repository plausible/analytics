defmodule Plausible.SSRF.PoolsTest do
  # Test must be sync: patches the global DNS check and inspects the shared pool supervisor
  use ExUnit.Case, async: false
  use Plausible.Test.Support.DNS

  alias Plausible.SSRF
  alias Plausible.Test.Support.TLSServer

  require TLSServer

  @pool_sup Plausible.SSRF.Pools.PoolSupervisor

  describe "pool reuse" do
    TLSServer.setup_allow_loopback()

    test "repeat requests to the same host share one pool" do
      stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

      {ca, port} =
        TLSServer.start(
          cert_host: "good.example",
          handler: fn conn, _port -> Plug.Conn.send_resp(conn, 200, "ok") end
        )

      before = pool_count()

      assert {:ok, %Req.Response{status: 200}} = get(ca, "https://good.example:#{port}/")
      assert {:ok, %Req.Response{status: 200}} = get(ca, "https://good.example:#{port}/")

      assert pool_count() == before + 1
    end

    test "different hosts on the same IP get their own pool" do
      stub_dns(%{
        "a.example" => {[{127, 0, 0, 1}], []},
        "b.example" => {[{127, 0, 0, 1}], []}
      })

      handler = fn conn, _port -> Plug.Conn.send_resp(conn, 200, "ok") end
      {ca_a, port_a} = TLSServer.start(cert_host: "a.example", handler: handler)
      {ca_b, port_b} = TLSServer.start(cert_host: "b.example", handler: handler)

      before = pool_count()

      assert {:ok, %Req.Response{status: 200}} = get(ca_a, "https://a.example:#{port_a}/")
      assert {:ok, %Req.Response{status: 200}} = get(ca_b, "https://b.example:#{port_b}/")

      assert pool_count() == before + 2
    end
  end

  # DynamicSupervisor with a short idle time so the idle shutdown is observable
  describe "idle shutdown" do
    setup do
      finch = Module.concat(__MODULE__, Finch)
      sup = Module.concat(__MODULE__, PoolSupervisor)
      start_supervised!({Finch, name: finch})
      start_supervised!({DynamicSupervisor, name: sup, strategy: :one_for_one})
      {:ok, finch: finch, sup: sup}
    end

    @tag :capture_log
    test "a used pool shuts down once idle, and a later request starts a fresh one",
         %{finch: finch, sup: sup} do
      {ca, port} =
        TLSServer.start(
          cert_host: "good.example",
          handler: fn conn, _port -> Plug.Conn.send_resp(conn, 200, "ok") end
        )

      start_pool = fn ->
        pool = %Finch.Pool{scheme: :https, host: "127.0.0.1", port: port, tag: "good.example"}

        spec =
          Finch.Pool.child_spec(
            finch: finch,
            pool: pool,
            pool_max_idle_time: 100,
            conn_opts: [hostname: "good.example", transport_opts: [cacerts: [ca]]]
          )

        DynamicSupervisor.start_child(sup, spec)
      end

      request = fn ->
        Finch.build(:get, "https://127.0.0.1:#{port}/", [{"host", "good.example"}], nil,
          pool_tag: "good.example"
        )
        |> Finch.request(finch)
      end

      assert {:ok, _pid} = start_pool.()
      # Starting the same pool tagged with {scheme, host, port, tag} again is a no-op
      assert {:error, {:already_started, _pid}} = start_pool.()

      assert {:ok, %Finch.Response{status: 200}} = request.()
      assert pool_count(sup) == 1

      # Checked out pool shuts down after the idle window
      assert Plausible.TestUtils.eventually(fn -> {pool_count(sup) == 0, true} end)

      # Fresh start
      assert {:ok, _pid} = start_pool.()
      assert {:ok, %Finch.Response{status: 200}} = request.()
    end
  end

  defp get(ca, url, opts \\ []) do
    SSRF.get(url, [cacerts: [ca]] ++ opts)
  end

  defp pool_count(sup \\ @pool_sup) do
    DynamicSupervisor.count_children(sup).active
  end
end
