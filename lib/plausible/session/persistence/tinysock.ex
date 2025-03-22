defmodule Plausible.Session.Persistence.TinySock do
  @moduledoc ~S"""
  Communication over Unix domain sockets.

  ## Usage

  ```elixir
  TinySock.server(
    base_path: "/tmp",
    handler: fn
      {"DUMP-ETS", requested_version, path} ->
        if requested_version == SessionV2.module_info[:md5] do
          for tab <- [:sessions1, :sessions2, :sessions3] do
            :ok = :ets.tab2file(tab, Path.join(path, "ets#{tab}"))
          end

          :ok
        else
          {:error, :invalid_version}
        end
    end
  )

  dump_path = "/tmp/ysSEjw"
  File.mkdir_p!(dump_path)
  [sock_path] = TinySock.list("/tmp")

  with :ok <- TinySock.call(sock_path, {"DUMP-ETS", SessionV2.module_info[:md5], dump_path}) do
    for "ets" <> tab <- File.ls!(dump_path) do
      :ets.file2tab(Path.join(dump_path, tab))
    end
  end
  ```
  """

  use GenServer, restart: :transient
  require Logger

  @listen_opts [:binary, packet: :raw, nodelay: true, backlog: 128, active: false]
  @connect_opts [:binary, packet: :raw, nodelay: true, active: false]

  @tag_data "tinysock"
  @tag_data_size byte_size(@tag_data)

  def server(opts), do: start_link(opts)
  def socket(server), do: GenServer.call(server, :socket)

  def acceptors(server) do
    :ets.tab2list(GenServer.call(server, :acceptors))
  end

  def stop(server), do: GenServer.stop(server)

  @doc "TODO"
  def list(base_path) do
    with {:ok, names} <- File.ls(base_path) do
      sock_paths =
        for @tag_data <> _rand = name <- names do
          Path.join(base_path, name)
        end

      {:ok, sock_paths}
    end
  end

  @doc "TODO"
  def call(sock_path, message, timeout \\ :timer.seconds(5)) do
    with {:ok, socket} <- sock_connect_or_rm(sock_path, timeout) do
      try do
        with :ok <- sock_send(socket, :erlang.term_to_binary(message)) do
          sock_recv(socket, timeout)
        end
      after
        sock_shut_and_close(socket)
      end
    end
  end

  @doc false
  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, [:debug, :name, :spawn_opt, :hibernate_after])
    base_path = Keyword.fetch!(opts, :base_path)
    handler = Keyword.fetch!(opts, :handler)

    case File.mkdir_p(base_path) do
      :ok ->
        GenServer.start_link(__MODULE__, {base_path, handler}, gen_opts)

      {:error, reason} ->
        Logger.warning(
          "tinysock failed to create directory at #{inspect(base_path)}, reason: #{inspect(reason)}"
        )

        :ignore
    end
  end

  @impl true
  def init({base_path, handler}) do
    case sock_listen_or_retry(base_path) do
      {:ok, socket} ->
        acceptors = :ets.new(:acceptors, [:protected])
        state = {socket, acceptors, handler}
        for _ <- 1..10, do: spawn_acceptor(state)
        {:ok, state}

      {:error, reason} ->
        Logger.warning(
          "tinysock failed to open a listen socket in #{inspect(base_path)}, reason: #{inspect(reason)}"
        )

        :ignore
    end
  end

  @impl true
  def handle_call(:acceptors, _from, {_socket, acceptors, _handler} = state) do
    {:reply, acceptors, state}
  end

  def handle_call(:socket, _from, {socket, _acceptors, _handler} = state) do
    {:reply, socket, state}
  end

  @impl true
  def handle_cast(:accepted, {socket, _acceptors, _handler} = state) do
    if socket, do: spawn_acceptor(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case reason do
      :normal ->
        remove_acceptor(state, pid)
        {:noreply, state}

      :emfile ->
        raise File.Error, reason: reason, action: "accept socket", path: "tinysock lol"

      reason ->
        # :telemetry.execute([:reuse, :acceptor, :crash], reason)
        Logger.error("tinysock acceptor crashed, reason: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp remove_acceptor({_socket, acceptors, _handler}, pid) do
    :ets.delete(acceptors, pid)
  end

  defp spawn_acceptor({socket, acceptors, handler}) do
    {pid, _ref} =
      :proc_lib.spawn_opt(
        __MODULE__,
        :accept_loop,
        [_parent = self(), socket, handler],
        [:monitor]
      )

    :ets.insert(acceptors, {pid})
  end

  @doc false
  def accept_loop(parent, listen_socket, handler) do
    case :gen_tcp.accept(listen_socket, :timer.seconds(5)) do
      {:ok, socket} ->
        GenServer.cast(parent, :accepted)
        handle_message(socket, handler)

      {:error, :timeout} ->
        accept_loop(parent, listen_socket, handler)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        exit(reason)
    end
  end

  defp handle_message(socket, handler) do
    {:ok, message} = sock_recv(socket, _timeout = :timer.seconds(5))
    sock_send(socket, :erlang.term_to_binary(handler.(message)))
  after
    sock_shut_and_close(socket)
  end

  defp sock_listen_or_retry(base_path) do
    sock_name = @tag_data <> Base.url_encode64(:crypto.strong_rand_bytes(4), padding: false)
    sock_path = Path.join(base_path, sock_name)

    case :gen_tcp.listen(0, [{:ifaddr, {:local, sock_path}} | @listen_opts]) do
      {:ok, socket} -> {:ok, socket}
      {:error, :eaddrinuse} -> sock_listen_or_retry(base_path)
      {:error, reason} -> {:error, reason}
    end
  end

  defp sock_connect_or_rm(sock_path, timeout) do
    case :gen_tcp.connect({:local, sock_path}, 0, @connect_opts, timeout) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, :timeout} = error ->
        error

      {:error, _reason} = error ->
        Logger.notice(
          "tinysock failed to connect to #{inspect(sock_path)}, reason: #{inspect(error)}"
        )

        _ = File.rm(sock_path)
        error
    end
  end

  defp sock_send(socket, binary) do
    :gen_tcp.send(socket, <<@tag_data, byte_size(binary)::64, binary::bytes>>)
  end

  defp sock_recv(socket, timeout) do
    with {:ok, <<@tag_data, size::64>>} <- :gen_tcp.recv(socket, @tag_data_size + 8, timeout),
         {:ok, binary} <- :gen_tcp.recv(socket, size, timeout) do
      try do
        {:ok, :erlang.binary_to_term(binary, [:safe])}
      rescue
        e -> {:error, e}
      end
    end
  end

  defp sock_shut_and_close(socket) do
    :gen_tcp.shutdown(socket, :read_write)
    :gen_tcp.close(socket)
  end
end
