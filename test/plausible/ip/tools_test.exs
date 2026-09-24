defmodule Plausible.IP.ToolsTest do
  use ExUnit.Case, async: true

  alias Plausible.IP

  defp ip!(str) do
    {:ok, ip} = :inet.parse_address(String.to_charlist(str))
    ip
  end

  describe "reserved?/1 - IPv4" do
    test "RFC 1918 private-use ranges" do
      assert IP.Tools.reserved?(ip!("10.0.0.0"))
      assert IP.Tools.reserved?(ip!("10.255.255.255"))
      assert IP.Tools.reserved?(ip!("172.16.0.0"))
      assert IP.Tools.reserved?(ip!("172.31.255.255"))
      assert IP.Tools.reserved?(ip!("192.168.0.0"))
      assert IP.Tools.reserved?(ip!("192.168.255.255"))

      refute IP.Tools.reserved?(ip!("172.15.255.255"))
      refute IP.Tools.reserved?(ip!("172.32.0.0"))
      refute IP.Tools.reserved?(ip!("11.0.0.0"))
      refute IP.Tools.reserved?(ip!("192.167.255.255"))
      refute IP.Tools.reserved?(ip!("192.169.0.0"))
    end

    test "loopback 127.0.0.0/8" do
      assert IP.Tools.reserved?(ip!("127.0.0.1"))
      assert IP.Tools.reserved?(ip!("127.255.255.255"))
      refute IP.Tools.reserved?(ip!("126.255.255.255"))
      refute IP.Tools.reserved?(ip!("128.0.0.0"))
    end

    test "this-network 0.0.0.0/8" do
      assert IP.Tools.reserved?(ip!("0.0.0.0"))
      assert IP.Tools.reserved?(ip!("0.255.255.255"))
    end

    test "link-local 169.254.0.0/16" do
      assert IP.Tools.reserved?(ip!("169.254.0.0"))
      assert IP.Tools.reserved?(ip!("169.254.255.255"))
      refute IP.Tools.reserved?(ip!("169.253.255.255"))
      refute IP.Tools.reserved?(ip!("169.255.0.0"))
    end

    test "shared address space (CGNAT) 100.64.0.0/10" do
      assert IP.Tools.reserved?(ip!("100.64.0.0"))
      assert IP.Tools.reserved?(ip!("100.127.255.255"))
      refute IP.Tools.reserved?(ip!("100.63.255.255"))
      refute IP.Tools.reserved?(ip!("100.128.0.0"))
    end

    test "benchmarking 198.18.0.0/15" do
      assert IP.Tools.reserved?(ip!("198.18.0.0"))
      assert IP.Tools.reserved?(ip!("198.19.255.255"))
      refute IP.Tools.reserved?(ip!("198.17.255.255"))
      refute IP.Tools.reserved?(ip!("198.20.0.0"))
    end

    test "documentation TEST-NET ranges" do
      assert IP.Tools.reserved?(ip!("192.0.2.0"))
      assert IP.Tools.reserved?(ip!("192.0.2.255"))
      assert IP.Tools.reserved?(ip!("198.51.100.0"))
      assert IP.Tools.reserved?(ip!("198.51.100.255"))
      assert IP.Tools.reserved?(ip!("203.0.113.0"))
      assert IP.Tools.reserved?(ip!("203.0.113.255"))
    end

    test "reserved-for-future-use 240.0.0.0/4 (class E)" do
      assert IP.Tools.reserved?(ip!("240.0.0.0"))
      assert IP.Tools.reserved?(ip!("255.255.255.254"))
    end

    test "limited broadcast 255.255.255.255/32" do
      assert IP.Tools.reserved?(ip!("255.255.255.255"))
    end

    test "multicast 224.0.0.0/4" do
      assert IP.Tools.reserved?(ip!("224.0.0.0"))
      assert IP.Tools.reserved?(ip!("224.0.0.1"))
      assert IP.Tools.reserved?(ip!("239.255.255.255"))
      refute IP.Tools.reserved?(ip!("223.255.255.255"))
    end

    test "IETF protocol assignments 192.0.0.0/24 but not its globally reachable carve-outs" do
      assert IP.Tools.reserved?(ip!("192.0.0.0"))
      assert IP.Tools.reserved?(ip!("192.0.0.8"))
      assert IP.Tools.reserved?(ip!("192.0.0.170"))
      assert IP.Tools.reserved?(ip!("192.0.0.171"))

      refute IP.Tools.reserved?(ip!("192.0.0.9"))
      refute IP.Tools.reserved?(ip!("192.0.0.10"))
    end

    test "AS112/AMT anycast carve-outs are globally reachable, not reserved" do
      refute IP.Tools.reserved?(ip!("192.31.196.1"))
      refute IP.Tools.reserved?(ip!("192.52.193.1"))
      refute IP.Tools.reserved?(ip!("192.175.48.1"))
    end

    test "deprecated 6to4 relay anycast block reverted to ordinary space" do
      refute IP.Tools.reserved?(ip!("192.88.99.1"))
      assert IP.Tools.reserved?(ip!("192.88.99.2"))
    end

    test "well-known public addresses are not reserved" do
      refute IP.Tools.reserved?(ip!("8.8.8.8"))
      refute IP.Tools.reserved?(ip!("1.1.1.1"))
      refute IP.Tools.reserved?(ip!("93.184.216.34"))
      refute IP.Tools.reserved?(ip!("172.217.0.0"))
    end
  end

  describe "reserved?/1 - IPv6" do
    test "loopback and unspecified" do
      assert IP.Tools.reserved?(ip!("::1"))
      assert IP.Tools.reserved?(ip!("::"))
    end

    test "unique local addresses fc00::/7" do
      assert IP.Tools.reserved?(ip!("fc00::1"))
      assert IP.Tools.reserved?(ip!("fd00::1"))
      refute IP.Tools.reserved?(ip!("fe00::1"))
    end

    test "link-local unicast fe80::/10" do
      assert IP.Tools.reserved?(ip!("fe80::1"))
      assert IP.Tools.reserved?(ip!("febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff"))
      refute IP.Tools.reserved?(ip!("fec0::1"))
    end

    test "documentation ranges" do
      assert IP.Tools.reserved?(ip!("2001:db8::1"))
      assert IP.Tools.reserved?(ip!("3fff::1"))
    end

    test "benchmarking and discard-only blocks" do
      assert IP.Tools.reserved?(ip!("2001:2::1"))
      assert IP.Tools.reserved?(ip!("100::1"))
    end

    test "multicast ff00::/8" do
      assert IP.Tools.reserved?(ip!("ff02::1"))
      assert IP.Tools.reserved?(ip!("ff00::"))
      refute IP.Tools.reserved?(ip!("feff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"))
    end

    test "IETF protocol assignments 2001::/23 is reserved by default" do
      assert IP.Tools.reserved?(ip!("2001:5::1"))
      assert IP.Tools.reserved?(ip!("2001:1ff::1"))
    end

    test "carve-outs inside 2001::/23 that are globally reachable are not reserved" do
      refute IP.Tools.reserved?(ip!("2001:1::1"))
      refute IP.Tools.reserved?(ip!("2001:1::2"))
      refute IP.Tools.reserved?(ip!("2001:1::3"))
      refute IP.Tools.reserved?(ip!("2001:3::1"))
      refute IP.Tools.reserved?(ip!("2001:4:112::1"))
      refute IP.Tools.reserved?(ip!("2001:20::1"))
      refute IP.Tools.reserved?(ip!("2001:30::1"))
    end

    test "TEREDO 2001::/32 is not treated as reserved" do
      refute IP.Tools.reserved?(ip!("2001:0:4136:e378:8000:63bf:3fff:fdd2"))
    end

    test "6to4 2002::/16 is not treated as reserved" do
      refute IP.Tools.reserved?(ip!("2002:c000:0204::"))
    end

    test "deprecated ORCHID block reverted to ordinary space" do
      refute IP.Tools.reserved?(ip!("2001:10::1"))
    end

    test "well-known public addresses are not reserved" do
      refute IP.Tools.reserved?(ip!("2606:4700:4700::1111"))
      refute IP.Tools.reserved?(ip!("2001:4860:4860::8888"))
    end
  end

  describe "reserved?/1 - IPv4-mapped IPv6 (::ffff:a.b.c.d)" do
    test "delegates to the embedded IPv4 address instead of blanket-reserving ::ffff:0:0/96" do
      assert IP.Tools.reserved?(ip!("::ffff:127.0.0.1"))
      assert IP.Tools.reserved?(ip!("::ffff:10.0.0.1"))
      assert IP.Tools.reserved?(ip!("::ffff:192.168.1.1"))

      refute IP.Tools.reserved?(ip!("::ffff:8.8.8.8"))
      refute IP.Tools.reserved?(ip!("::ffff:1.1.1.1"))
    end

    test "matches reserved?/1 applied directly to the embedded address" do
      for str <- ["127.0.0.1", "10.1.2.3", "8.8.8.8", "192.0.2.1", "224.0.0.1"] do
        {a, b, c, d} = v4 = ip!(str)
        mapped = {0, 0, 0, 0, 0, 0xFFFF, a * 256 + b, c * 256 + d}

        assert IP.Tools.reserved?(mapped) == IP.Tools.reserved?(v4),
               "expected ::ffff:#{str} to match reserved?/1 of #{str}"
      end
    end
  end

  describe "allowed?/1" do
    test "accepts already-parsed tuples" do
      assert IP.Tools.allowed?({8, 8, 8, 8})
      refute IP.Tools.allowed?({127, 0, 0, 1})
      assert IP.Tools.allowed?({0x2606, 0x4700, 0x4700, 0, 0, 0, 0, 0x1111})
      refute IP.Tools.allowed?({0, 0, 0, 0, 0, 0, 0, 1})
    end

    test "accepts binaries" do
      assert IP.Tools.allowed?("8.8.8.8")
      refute IP.Tools.allowed?("192.168.1.1")
      assert IP.Tools.allowed?("2606:4700:4700::1111")
      refute IP.Tools.allowed?("::1")
    end

    test "disallows invalid inputs" do
      refute IP.Tools.allowed?({1, 2, 3})
      refute IP.Tools.allowed?({1, 2, 3, 4, 5})
      refute IP.Tools.allowed?(nil)
      refute IP.Tools.allowed?(:not_an_ip)
      refute IP.Tools.allowed?("not an ip")
      refute IP.Tools.allowed?("")
      refute IP.Tools.allowed?("999.999.999.999")
    end
  end

  describe "ranges/0" do
    test "every range is well formed" do
      ranges = IP.Tools.ranges()

      assert length(ranges) > 30

      for %{cidr: cidr, reserved: reserved, name: name} <- ranges do
        assert is_binary(cidr)
        assert is_binary(name)
        assert is_boolean(reserved)
      end
    end

    test "is sorted from most to least specific prefix" do
      prefix_lengths =
        Enum.map(IP.Tools.ranges(), fn %{cidr: cidr} ->
          [_addr, prefix] = String.split(cidr, "/")
          String.to_integer(prefix)
        end)

      assert prefix_lengths == Enum.sort(prefix_lengths, :desc)
    end

    test "includes the supplemental multicast ranges" do
      cidrs = Enum.map(IP.Tools.ranges(), & &1.cidr)

      assert "224.0.0.0/4" in cidrs
      assert "ff00::/8" in cidrs
    end

    test "excludes ::ffff:0:0/96 in favor of delegating to IPv4 rules" do
      refute "::ffff:0:0/96" in Enum.map(IP.Tools.ranges(), & &1.cidr)
    end
  end
end
