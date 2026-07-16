defmodule Plausible.IP.Tools do
  @moduledoc """
  Recognizes reserved and private IPv4/IPv6 addresses.
  See: `Plausible.IP.Tools.Registry`
  """

  @external_resource Plausible.IP.Tools.Registry.ipv4_registry_path()
  @external_resource Plausible.IP.Tools.Registry.ipv6_registry_path()

  @clauses Plausible.IP.Tools.Registry.entries()

  @doc """
  Returns the ranges used in `reserved?/1`, for testing purposes.
  """
  @spec ranges() :: [%{cidr: String.t(), name: String.t(), reserved: boolean()}]
  def ranges do
    Enum.map(@clauses, &Map.take(&1, [:cidr, :name, :reserved]))
  end

  @doc """
  Determines whether IP falls within a reserved or private address range.
  Accepts already parsed `:inet` address tuples.

  IPv4-mapped IPv6 addresses (`::ffff:a.b.c.d`) are unwrapped and delegate to
  the IPv4 rules for the embedded address, rather than being uniformly
  treated as reserved.
  """
  @spec reserved?(:inet.ip_address()) :: boolean()
  for %{pattern: pattern, guard: guard, reserved: reserved} <- @clauses do
    def reserved?(unquote(pattern)) when unquote(guard), do: unquote(reserved)
  end

  def reserved?({0, 0, 0, 0, 0, 0xFFFF, hi, lo}) do
    reserved?({div(hi, 256), rem(hi, 256), div(lo, 256), rem(lo, 256)})
  end

  def reserved?(ip) when is_tuple(ip) and tuple_size(ip) == 4, do: false
  def reserved?(ip) when is_tuple(ip) and tuple_size(ip) == 8, do: false

  @doc """
  Determines if IP is allowed, i.e. valid and not reserved/private.
  """
  @spec allowed?(:inet.ip_address() | String.t()) :: boolean()
  def allowed?(ip) when is_binary(ip) do
    case :inet.parse_address(String.to_charlist(ip)) do
      {:ok, address} -> allowed?(address)
      {:error, _reason} -> false
    end
  end

  def allowed?(ip) when is_tuple(ip) and tuple_size(ip) in [4, 8] do
    not reserved?(ip)
  end

  def allowed?(_ip), do: false
end
