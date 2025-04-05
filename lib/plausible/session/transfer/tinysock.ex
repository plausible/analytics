defmodule Plausible.Session.Transfer.TinySock do
  @moduledoc false
  use GenServer
  require Logger

  @tag_data "tinysock"
  @tag_size byte_size(@tag_data)

  @spec list!(Path.t()) :: [Path.t()]
  def list!(base_path) do
    for @tag_data <> _rand = name <- File.ls!(base_path) do
      Path.join(base_path, name)
    end
  end

  @spec call(Path.t(), term, timeout) :: {:ok, reply :: term} | {:error, :timeout | :inet.posix()}
  def call(sock_path, message, timeout \\ :timer.seconds(5)) do
    with {:ok, socket} <- sock_connect_or_rm(sock_path, timeout) do
      try do
        with :ok <- sock_send(socket, :erlang.term_to_iovec(message)) do
          sock_recv(socket, timeout)
        end
      after
        sock_shut_and_close(socket)
      end
    end
  end

  def start_link(opts) do
    base_path = Keyword.fetch!(opts, :base_path)
    handler = Keyword.fetch!(opts, :handler)
    GenServer.start_link(__MODULE__, {base_path, handler})
  end

  @impl true
  def init({base_path, handler}) do
    File.mkdir_p!(base_path)
    socket = sock_listen_or_retry!(base_path)

    Process.flag(:trap_exit, true)
    state = %{socket: socket, handler: handler}
    for _ <- 1..10, do: spawn_acceptor(state)

    {:ok, state}
  end

  @impl true
  def handle_cast(:accepted, state) do
    spawn_acceptor(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    case reason do
      :normal ->
        {:noreply, state}

      :emfile ->
        Logger.error("tinysock ran out of file descriptors, stopping")
        {:stop, reason, state}

      reason ->
        log = "tinysock request handler #{inspect(pid)} terminating\n" <> format_error(reason)
        Logger.error(log, crash_reason: reason)
        {:noreply, state}
    end
  end

  defp format_error(reason) do
    case reason do
      {e, stacktrace} when is_list(stacktrace) -> Exception.format(:error, e, stacktrace)
      _other -> Exception.format(:exit, reason)
    end
  end

  @impl true
  def terminate(reason, %{socket: socket}) do
    with {:ok, {:local, path}} <- :inet.sockname(socket), do: File.rm(path)
    reason
  end

  defp spawn_acceptor(%{socket: socket, handler: handler}) do
    :proc_lib.spawn_link(__MODULE__, :accept_loop, [_parent = self(), socket, handler])
  end

  @doc false
  def accept_loop(parent, listen_socket, handler) do
    case :gen_tcp.accept(listen_socket, :infinity) do
      {:ok, socket} ->
        GenServer.cast(parent, :accepted)
        handle_message(socket, handler)

      {:error, reason} ->
        exit(reason)
    end
  end

  defp handle_message(socket, handler) do
    {:ok, message} = sock_recv(socket, _timeout = :timer.seconds(5))
    sock_send(socket, :erlang.term_to_iovec(handler.(message)))
  after
    sock_shut_and_close(socket)
  end

  @listen_opts mode: :binary, packet: :raw, nodelay: true, active: false, backlog: 1024
  @connect_opts mode: :binary, packet: :raw, nodelay: true, active: false

  defp sock_listen_or_retry!(base_path) do
    sock_name = @tag_data <> Base.url_encode64(:crypto.strong_rand_bytes(4), padding: false)
    sock_path = Path.join(base_path, sock_name)

    case :gen_tcp.listen(0, [{:ifaddr, {:local, sock_path}} | @listen_opts]) do
      {:ok, socket} -> socket
      {:error, :eaddrinuse} -> sock_listen_or_retry!(base_path)
      {:error, reason} -> raise File.Error, path: sock_path, reason: reason, action: "bind"
    end
  end

  defp sock_connect_or_rm(sock_path, timeout) do
    case :gen_tcp.connect({:local, sock_path}, 0, @connect_opts, timeout) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, reason} = error ->
        if reason != :timeout do
          # removes stale socket file
          # possible - but unlikely - race condition
          File.rm(sock_path)
        end

        error
    end
  end

  @dialyzer :no_improper_lists
  defp sock_send(socket, data) do
    :gen_tcp.send(socket, [<<@tag_data, IO.iodata_length(data)::64-little>> | data])
  end

  defp sock_recv(socket, timeout) do
    with {:ok, <<@tag_data, size::64-little>>} <- :gen_tcp.recv(socket, @tag_size + 8, timeout),
         {:ok, binary} <- sock_recv_continue(socket, size, timeout, []) do
      try do
        {:ok, :erlang.binary_to_term(binary, [:safe])}
      rescue
        e -> {:error, e}
      end
    end
  end

  @five_mb 5 * 1024 * 1024

  # for larger messages (>64MB) we need to read in chunks or we get {:error, :enomem}
  defp sock_recv_continue(socket, size, timeout, acc) do
    with {:ok, data} <- :gen_tcp.recv(socket, min(size, @five_mb), timeout) do
      acc = [acc | data]

      case size - byte_size(data) do
        0 -> {:ok, IO.iodata_to_binary(acc)}
        left -> sock_recv_continue(socket, left, timeout, acc)
      end
    end
  end

  defp sock_shut_and_close(socket) do
    :gen_tcp.shutdown(socket, :read_write)
    :gen_tcp.close(socket)
  end
end
