defmodule Plausible.Session.Transfer.TinySockTest do
  use ExUnit.Case, async: true

  alias Plausible.Session.Transfer.TinySock

  setup do
  end

  test "it works", %{tmp_dir: tmp_dir} do
    server = start_supervised!({TinySock, base_path: tmp_dir, handler: fn :ping -> :pong end})
    assert {:ok, {:local, sock_path}} = :inet.sockname(TinySock.listen_socket(server))
    assert {:ok, [^sock_path]} = TinySock.list(tmp_dir)
    assert {:ok, :pong} = TinySock.call(sock_path, :ping)
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
end
