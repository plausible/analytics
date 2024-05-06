defmodule Plausible.DebugReplayInfo do
  @moduledoc """
  Function execution context (with arguments) to Sentry reports.
  """

  require Logger

  defmacro __using__(_) do
    quote do
      require Plausible.DebugReplayInfo
      import Plausible.DebugReplayInfo, only: [include_sentry_replay_info: 0]
    end
  end

  defmacro include_sentry_replay_info() do
    module = __CALLER__.module
    {function, arity} = __CALLER__.function
    f = Function.capture(module, function, arity)

    quote bind_quoted: [f: f] do
      replay_info =
        {f, binding()}
        |> :erlang.term_to_iovec([:compressed])
        |> IO.iodata_to_binary()
        |> Base.encode64()

      payload_size = byte_size(replay_info)

      if payload_size <= 10_000 do
        Sentry.Context.set_extra_context(%{
          debug_replay_info: replay_info,
          debug_replay_info_size: payload_size
        })
      else
        Sentry.Context.set_extra_context(%{
          debug_replay_info: :too_large,
          debug_replay_info_size: payload_size
        })
      end

      :ok
    end
  end

  @spec deserialize(String.t()) :: any()
  def deserialize(replay_info) do
    replay_info
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end
end
