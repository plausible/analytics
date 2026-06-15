defmodule Plausible.SSRFProtection do
  @moduledoc """
  Helpers for protecting against Server-Side Request Forgery (SSRF).

  User-controlled hostnames (custom verification URLs, site `data_domain`s,
  SSO domains) eventually get dereferenced by an outbound HTTP client or by
  Browserless. Before that happens the resolved IP addresses must be checked:
  a publicly resolvable hostname can point at a private, loopback, link-local
  (cloud metadata at `169.254.169.254`), CGNAT, multicast, or otherwise
  non-routable address and turn an innocent fetch into an internal request.

  This module only classifies addresses; DNS resolution stays with the caller
  (`Plausible.DnsLookup`) so the logic remains pure and trivially testable.

  Note: classifying the resolved IP does not by itself close the DNS-rebinding
  gap — a downstream consumer that re-resolves the host (e.g. Browserless) can
  still be handed a different answer. Pinning the resolved IP or running the
  consumer behind an egress filter is a deployment-level concern.
  """

  import Bitwise

  @type ip :: :inet.ip4_address() | :inet.ip6_address()

  @doc """
  Returns `true` when `ip` is NOT a publicly routable unicast address and must
  therefore never be the target of an outbound request.
  """
  @spec internal_ip?(ip()) :: boolean()
  def internal_ip?({a, b, c, d})
      when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) do
    internal_ipv4?(a, b, c, d)
  end

  def internal_ip?({a, b, c, d, e, f, g, h})
      when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) and
             is_integer(e) and is_integer(f) and is_integer(g) and is_integer(h) do
    internal_ipv6?({a, b, c, d, e, f, g, h})
  end

  @doc """
  Returns `true` when `ips` is empty or any address in it is internal.

  A host must be rejected if *any* of its resolved addresses is internal,
  because the HTTP client may connect to any of them. An empty list (no
  record / lookup failure) is treated as unsafe.
  """
  @spec any_internal?([ip()]) :: boolean()
  def any_internal?([]), do: true
  def any_internal?(ips) when is_list(ips), do: Enum.any?(ips, &internal_ip?/1)

  # IPv4 -------------------------------------------------------------------

  defp internal_ipv4?(0, _, _, _), do: true
  defp internal_ipv4?(10, _, _, _), do: true
  defp internal_ipv4?(127, _, _, _), do: true
  defp internal_ipv4?(100, b, _, _) when b in 64..127, do: true
  defp internal_ipv4?(169, 254, _, _), do: true
  defp internal_ipv4?(172, b, _, _) when b in 16..31, do: true
  defp internal_ipv4?(192, 0, 0, _), do: true
  defp internal_ipv4?(192, 168, _, _), do: true
  defp internal_ipv4?(198, b, _, _) when b in 18..19, do: true
  # 224.0.0.0/4 multicast, 240.0.0.0/4 reserved, 255.255.255.255 broadcast
  defp internal_ipv4?(a, _, _, _) when a >= 224, do: true
  defp internal_ipv4?(_, _, _, _), do: false

  # IPv6 -------------------------------------------------------------------

  defp internal_ipv6?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  defp internal_ipv6?({0, 0, 0, 0, 0, 0, 0, 1}), do: true

  # IPv4-mapped (::ffff:a.b.c.d) — re-check the embedded IPv4 address.
  defp internal_ipv6?({0, 0, 0, 0, 0, 0xFFFF, g, h}), do: embedded_ipv4_internal?(g, h)

  # Deprecated IPv4-compatible (::a.b.c.d). `::` and `::1` are matched above;
  # everything else in `::/96` carries an embedded IPv4, so re-check it.
  defp internal_ipv6?({0, 0, 0, 0, 0, 0, g, h}), do: embedded_ipv4_internal?(g, h)

  # NAT64 well-known prefix (64:ff9b::a.b.c.d) — translated to the embedded
  # IPv4 on the wire, so it can reach a private target on a NAT64 deployment.
  defp internal_ipv6?({0x0064, 0xFF9B, 0, 0, 0, 0, g, h}), do: embedded_ipv4_internal?(g, h)

  # 6to4 (2002:a.b.c.d::/16) — embedded IPv4 sits in the 2nd and 3rd groups.
  defp internal_ipv6?({0x2002, b, c, _, _, _, _, _}), do: embedded_ipv4_internal?(b, c)

  defp internal_ipv6?({a, _, _, _, _, _, _, _}) do
    cond do
      (a &&& 0xFE00) == 0xFC00 -> true
      (a &&& 0xFFC0) == 0xFE80 -> true
      (a &&& 0xFF00) == 0xFF00 -> true
      true -> false
    end
  end

  defp embedded_ipv4_internal?(g, h) do
    internal_ipv4?(g >>> 8, g &&& 0xFF, h >>> 8, h &&& 0xFF)
  end
end
