defmodule Plausible.DnsLookupInterface do
  @moduledoc """
  Behaviour module for DNS lookup operations.
  """

  @callback lookup(
              name :: charlist(),
              class :: atom(),
              type :: atom(),
              opts :: list(),
              timeout :: integer()
            ) ::
              list() | []
end

defmodule Plausible.DnsLookup do
  @moduledoc """
  Thin wrapper around `:inet_res.lookup/5`.
  To use, call `Plausible.DnsLookup.impl().lookup/5`,
  this allows for mocking DNS lookups in tests.
  """

  @behaviour Plausible.DnsLookupInterface

  @impl Plausible.DnsLookupInterface
  def lookup(name, class, type, opts, timeout),
    do: :inet_res.lookup(name, class, type, opts, timeout)

  @spec impl() :: Plausible.DnsLookup
  def impl(), do: Application.get_env(:plausible, :dns_lookup_impl, __MODULE__)
end
