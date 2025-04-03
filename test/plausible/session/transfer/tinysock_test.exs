defmodule Plausible.Session.Transfer.TinySockTest do
  use ExUnit.Case, async: true

  alias Plausible.Session.Transfer.TinySock

  setup do
    {:ok, tmp_dir: tmp_dir()}
  end

  # normal `@tag :tmp_dir` might not work if the path is too long for unix domain sockets (>104)
  # this one makes paths a bit shorter like "/tmp/plausible-1320/"
  defp tmp_dir do
    tmp_dir = Path.join(System.tmp_dir!(), "plausible-#{System.unique_integer([:positive])}")
    if File.exists?(tmp_dir), do: File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    tmp_dir
  end

  test "it works", %{tmp_dir: tmp_dir} do
    base_path = Path.join(tmp_dir, "sessions")
    server = start_supervised!({TinySock, base_path: base_path, handler: fn :ping -> :pong end})
    sock_path = TinySock.listen_socket_path(server)
    assert String.starts_with?(sock_path, base_path)
    assert {:ok, [^sock_path]} = TinySock.list(base_path)
    assert {:ok, :pong} = TinySock.call(sock_path, :ping)
  end

  test "eaccess", %{tmp_dir: tmp_dir} do
    # create a directory with no write permissions
    File.mkdir_p!(tmp_dir)
    File.chmod!(tmp_dir, 0o444)

    assert {:error, :eacces} = TinySock.write_dir(tmp_dir)

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

    sock = TinySock.listen_socket_path(server)

    log =
      ExUnit.CaptureLog.capture_log([async: true], fn ->
        assert {:error, :closed} = TinySock.call(sock, :crash)
        :timer.sleep(100)
      end)

    assert log =~ "[error] tinysock request handler"
    assert log =~ "terminating"
    assert log =~ "(RuntimeError) crash"

    assert {:ok, :two} = TinySock.call(sock, :one)
  end

  test "can echo ~100MB", %{tmp_dir: tmp_dir} do
    server =
      start_supervised!({TinySock, base_path: tmp_dir, handler: fn {:echo, data} -> data end})

    # assert {:ok, [buffer: buffer, recbuf: recbuf, sndbuf: sndbuf]} =
    #          :inet.getopts(TinySock.listen_socket(server), [:buffer, :recbuf, :sndbuf])

    # assert buffer >= recbuf
    # assert buffer >= sndbuf

    sock = TinySock.listen_socket_path(server)
    data = Enum.map(1..100, fn _ -> :crypto.strong_rand_bytes(1024 * 1024) end)

    assert {:ok, ^data} = TinySock.call(sock, {:echo, data})
  end
end
