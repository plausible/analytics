defmodule Plausible.Session.Transfer.TinySockTest do
  use ExUnit.Case, async: true
  import Plausible.TestUtils, only: [tmp_dir: 0]

  alias Plausible.Session.Transfer.TinySock

  setup do
    {:ok, tmp_dir: tmp_dir()}
  end

  test "it works", %{tmp_dir: tmp_dir} do
    base_path = Path.join(tmp_dir, "sessions")
    server = start_supervised!({TinySock, base_path: base_path, handler: fn :ping -> :pong end})
    {:ok, sock_path} = listen_socket_path(server)
    assert String.starts_with?(sock_path, base_path)
    assert {:ok, [^sock_path]} = TinySock.list(base_path)
    assert {:ok, :pong} = TinySock.call(sock_path, :ping)
  end

  test "eaccess", %{tmp_dir: tmp_dir} do
    # create a directory with no write permissions
    File.chmod!(tmp_dir, 0o444)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        assert :ignore = TinySock.start_link(base_path: tmp_dir, handler: fn :ping -> :pong end)
      end)

    assert log =~ "tinysock failed to bind in"
    assert log =~ tmp_dir
    assert log =~ ":eacces"
  end

  test "eexist", %{tmp_dir: tmp_dir} do
    base_path = Path.join(tmp_dir, "file")
    File.touch!(base_path)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        assert :ignore = TinySock.start_link(base_path: base_path, handler: fn :ping -> :pong end)
      end)

    assert log =~ "[warning] tinysock failed to bind in"
    assert log =~ tmp_dir
    assert log =~ ":eexist"
  end

  test "handler crash", %{tmp_dir: tmp_dir} do
    server =
      start_supervised!(
        {TinySock,
         base_path: tmp_dir,
         handler: fn
           :one -> :two
           :crash -> raise "crash"
         end}
      )

    [sockpath] = TinySock.list(tmp_dir)

    log =
      ExUnit.CaptureLog.capture_log([async: true], fn ->
        assert {:error, :closed} = TinySock.call(sockpath, :crash)
        :timer.sleep(100)
      end)

    assert log =~ "[error] tinysock request handler"
    assert log =~ "terminating"
    assert log =~ "(RuntimeError) crash"

    assert {:ok, :two} = TinySock.call(sockpath, :one)
  end

  test "can echo ~100MB", %{tmp_dir: tmp_dir} do
    server =
      start_supervised!({TinySock, base_path: tmp_dir, handler: fn {:echo, data} -> data end})

    # assert {:ok, [buffer: buffer, recbuf: recbuf, sndbuf: sndbuf]} =
    #          :inet.getopts(TinySock.listen_socket(server), [:buffer, :recbuf, :sndbuf])

    # assert buffer >= recbuf
    # assert buffer >= sndbuf

    data = Enum.map(1..100, fn _ -> :crypto.strong_rand_bytes(1024 * 1024) end)
    [sockpath] = TinySock.list(tmp_dir)
    assert {:ok, ^data} = TinySock.call(sockpath, {:echo, data})
  end
end
