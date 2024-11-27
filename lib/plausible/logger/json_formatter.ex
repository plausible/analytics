defmodule Plausible.Logger.JSONFormatter do
  @moduledoc """
  JSON formatter for the default Logger handler.

  Based on [Logger.Formatter](https://github.com/elixir-lang/elixir/blob/main/lib/logger/lib/logger/formatter.ex)

  Usage:

      formatter = Plausible.Logger.JSONFormatter.new(metadata: [:request_id])
      config :logger, :default_handler, formatter: formatter

  Or at runtime:

      formatter = Plausible.Logger.JSONFormatter.new(metadata: [:request_id])
      :logger.update_handler_config(:default, :formatter, formatter)

  """

  defmodule Log do
    @moduledoc false
    defstruct [:fields]

    defimpl Jason.Encoder do
      def encode(%{fields: fields}, opts) do
        Jason.Encode.keyword(fields, opts)
      end
    end
  end

  def new(options) do
    utc_log? = options[:utc_log] || Application.fetch_env!(:logger, :utc_log)
    truncate = options[:truncate] || Application.fetch_env!(:logger, :truncate)
    metadata = options[:metadata] || []

    {__MODULE__, %{truncate: truncate, metadata: metadata, utc_log?: utc_log?}}
  end

  # TODO replace invalid UTF8 with � in msg and meta?
  #
  # iex(3)> Jason.encode_to_iodata!("\x61\xF0\x80\x80\x80b", escapt: :unicode_safe)
  # ** (Jason.EncodeError) invalid byte 0xF0 in <<97, 240, 128, 128, 128, 98>>
  #     (jason 1.4.4) lib/jason.ex:213: Jason.encode_to_iodata!/2
  #     iex:3: (file)
  #
  # iex(3)> :json.encode_binary_escape_all("\x61\xF0\x80\x80\x80b")
  # ** (ErlangError) Erlang error: {:invalid_byte, 240}
  #     (stdlib 6.0) json.erl:533: :json.invalid_byte/2
  #     iex:3: (file)
  #
  # iex(3)> Logger.Formatter.prune "\x61\xF0\x80\x80\x80b"
  # "a����b"

  @doc false
  @spec format(:logger.log_event(), map) :: iodata
  def format(%{meta: meta, level: level, msg: msg}, config) do
    %{metadata: metadata_keys, truncate: truncate, utc_log?: utc_log?} = config

    time = process_time(meta, utc_log?)

    json =
      try do
        msg = process_message(msg, meta, truncate)
        meta = process_meta(meta, metadata_keys)
        log = %Log{fields: [{"level", level}, {"time", time}, {"msg", msg} | meta]}
        Jason.encode_to_iodata!(log)
      catch
        kind, reason ->
          msg = Exception.format(kind, reason, __STACKTRACE__)
          log = %Log{fields: [{"level", "error"}, {"time", time}, {"msg", msg}]}
          Jason.encode_to_iodata!(log)
      end

    [json, ?\n]
  end

  defp process_time(meta, utc_log?) do
    system_time =
      case meta do
        %{time: time} when is_integer(time) and time >= 0 -> time
        _ -> :os.system_time(:microsecond)
      end

    {date, time} = Logger.Formatter.system_time_to_date_time_ms(system_time, utc_log?)
    format_time(date, time)
  end

  defp process_message({:string, msg}, _meta, truncate) when is_binary(msg) do
    Logger.Formatter.truncate(msg, truncate)
  end

  defp process_message({:report, report}, %{report_cb: callback}, truncate) do
    cond do
      is_function(callback, 1) and callback != (&:logger.format_otp_report/1) ->
        Logger.Formatter.truncate(callback.(report), truncate)

      is_function(callback, 2) ->
        callback.(report, %{depth: :unlimited, chars_limit: truncate, single_line: false})

      true ->
        format_report(report)
    end
  end

  defp process_message({:report, report}, _meta, _truncate) do
    format_report(report)
  end

  defp process_message({format, args}, _meta, truncate) do
    format |> Logger.Utils.scan_inspect(args, truncate) |> :io_lib.build_text()
  end

  defp format_report(report) do
    report =
      case report do
        _ when is_list(report) -> report
        _ when is_map(report) -> Map.to_list(report)
      end

    %Log{fields: process_meta_all(report)}
    |> Jason.encode_to_iodata!()
    |> Jason.Fragment.new()
  end

  defp process_meta(meta, keys) do
    case keys do
      :all -> meta |> Map.to_list() |> process_meta_all()
      _keys when is_list(keys) -> process_meta_keys(keys, meta)
    end
  end

  defp process_meta_all([{k, v} | rest]) do
    if kv = metadata(k, v) do
      [kv | process_meta_all(rest)]
    else
      process_meta_all(rest)
    end
  end

  defp process_meta_all(empty = []), do: empty

  defp process_meta_keys([k | rest], meta) do
    if kv = metadata(k, Map.get(meta, k)) do
      [kv | process_meta_keys(rest, meta)]
    else
      process_meta_keys(rest, meta)
    end
  end

  defp process_meta_keys(empty = [], _meta), do: empty

  defmacrop unsafe_fragment(data) do
    quote do
      Jason.Fragment.new([?", unquote_splicing(data), ?"])
    end
  end

  defp format_time(date, time) do
    unsafe_fragment([Logger.Formatter.format_date(date), ?\s, Logger.Formatter.format_time(time)])
  end

  # TODO
  defp metadata(:time, _), do: nil
  # TODO
  defp metadata(:level, _), do: nil
  # TODO
  defp metadata(:msg, _), do: nil
  defp metadata(:gl, _), do: nil
  defp metadata(:report_cb, _), do: nil
  defp metadata(_, nil), do: nil

  defp metadata(k, pid) when is_pid(pid) do
    {k, unsafe_fragment([:erlang.pid_to_list(pid)])}
  end

  defp metadata(k, atom) when is_atom(atom) do
    v =
      case Atom.to_string(atom) do
        "Elixir." <> rest -> rest
        other -> other
      end

    {k, v}
  end

  defp metadata(k, ref) when is_reference(ref) do
    ~c"#Ref" ++ rest = :erlang.ref_to_list(ref)
    {k, unsafe_fragment([rest])}
  end

  defp metadata(k, port) when is_port(port) do
    ~c"#Port" ++ rest = :erlang.port_to_list(port)
    {k, unsafe_fragment([rest])}
  end

  defp metadata(:mfa = k, {m, f, a}) when is_atom(m) and is_atom(f) and is_integer(a) do
    {k, Exception.format_mfa(m, f, a)}
  end

  defp metadata(:initial_call = k, {m, f, a}) when is_atom(m) and is_atom(f) and is_integer(a) do
    {k, Exception.format_mfa(m, f, a)}
  end

  defp metadata(:crash_reason = k, {exception, stacktrace}) when is_exception(exception) do
    {k, Exception.format(:error, exception, stacktrace)}
  end

  defp metadata(:file = k, v) when is_list(v) do
    {k, List.to_string(v)}
  end

  defp metadata(:function = k, v) when is_list(v) do
    {k, List.to_string(v)}
  end

  defp metadata(k, [{_k, _v} | _rest] = kv) do
    fields = process_meta_all(kv)

    nested =
      %Log{fields: fields}
      |> Jason.encode_to_iodata!()
      |> Jason.Fragment.new()

    {k, nested}
  end

  defp metadata(_, list) when is_list(list), do: _ignore = nil

  defp metadata(k, map) when is_map(map) do
    fields = process_meta_all(Map.to_list(map))

    nested =
      %Log{fields: fields}
      |> Jason.encode_to_iodata!()
      |> Jason.Fragment.new()

    {k, nested}
  end

  defp metadata(k, v) do
    cond do
      Jason.Encoder.impl_for(v) != Jason.Encoder.Any -> {k, v}
      impl = String.Chars.impl_for(v) -> {k, impl.to_string(v)}
      true -> _ignore = nil
    end
  end
end
