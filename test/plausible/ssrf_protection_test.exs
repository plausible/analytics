defmodule Plausible.SSRFProtectionTest do
  use ExUnit.Case, async: true

  alias Plausible.SSRFProtection

  describe "internal_ip?/1 with IPv4" do
    for ip <- [
          {0, 0, 0, 0},
          {10, 0, 0, 1},
          {127, 0, 0, 1},
          {100, 64, 0, 1},
          {100, 100, 50, 1},
          {169, 254, 169, 254},
          {172, 16, 0, 1},
          {172, 31, 255, 255},
          {192, 0, 0, 1},
          {192, 168, 1, 1},
          {198, 18, 0, 1},
          {224, 0, 0, 1},
          {239, 255, 255, 255},
          {255, 255, 255, 255}
        ] do
      test "rejects internal #{inspect(ip)}" do
        assert SSRFProtection.internal_ip?(unquote(Macro.escape(ip)))
      end
    end

    for ip <- [
          {1, 1, 1, 1},
          {8, 8, 8, 8},
          {93, 184, 216, 34},
          {172, 15, 0, 1},
          {172, 32, 0, 1},
          {100, 63, 0, 1},
          {100, 128, 0, 1},
          {198, 17, 0, 1},
          {198, 20, 0, 1}
        ] do
      test "accepts public #{inspect(ip)}" do
        refute SSRFProtection.internal_ip?(unquote(Macro.escape(ip)))
      end
    end
  end

  describe "internal_ip?/1 with IPv6" do
    for ip <- [
          {0, 0, 0, 0, 0, 0, 0, 0},
          {0, 0, 0, 0, 0, 0, 0, 1},
          {0xFC00, 0, 0, 0, 0, 0, 0, 1},
          {0xFD12, 0, 0, 0, 0, 0, 0, 1},
          {0xFE80, 0, 0, 0, 0, 0, 0, 1},
          {0xFF02, 0, 0, 0, 0, 0, 0, 1},
          # ::ffff:169.254.169.254 (IPv4-mapped metadata address)
          {0, 0, 0, 0, 0, 0xFFFF, 0xA9FE, 0xA9FE},
          # ::ffff:10.0.0.1
          {0, 0, 0, 0, 0, 0xFFFF, 0x0A00, 0x0001},
          # ::127.0.0.1 (deprecated IPv4-compatible loopback)
          {0, 0, 0, 0, 0, 0, 0x7F00, 0x0001},
          # 64:ff9b::169.254.169.254 (NAT64 metadata address)
          {0x0064, 0xFF9B, 0, 0, 0, 0, 0xA9FE, 0xA9FE},
          # 2002:0a00:0001:: (6to4 wrapping 10.0.0.1)
          {0x2002, 0x0A00, 0x0001, 0, 0, 0, 0, 0}
        ] do
      test "rejects internal #{inspect(ip)}" do
        assert SSRFProtection.internal_ip?(unquote(Macro.escape(ip)))
      end
    end

    for ip <- [
          {0x2606, 0x4700, 0x4700, 0, 0, 0, 0, 0x1111},
          # ::ffff:8.8.8.8 (IPv4-mapped public address)
          {0, 0, 0, 0, 0, 0xFFFF, 0x0808, 0x0808},
          # 64:ff9b::8.8.8.8 (NAT64 wrapping a public address)
          {0x0064, 0xFF9B, 0, 0, 0, 0, 0x0808, 0x0808},
          # 2002:0808:0808:: (6to4 wrapping 8.8.8.8)
          {0x2002, 0x0808, 0x0808, 0, 0, 0, 0, 0}
        ] do
      test "accepts public #{inspect(ip)}" do
        refute SSRFProtection.internal_ip?(unquote(Macro.escape(ip)))
      end
    end
  end

  describe "any_internal?/1" do
    test "treats empty list as unsafe" do
      assert SSRFProtection.any_internal?([])
    end

    test "is true when any address is internal" do
      assert SSRFProtection.any_internal?([{8, 8, 8, 8}, {10, 0, 0, 1}])
    end

    test "is false when all addresses are public" do
      refute SSRFProtection.any_internal?([{8, 8, 8, 8}, {1, 1, 1, 1}])
    end
  end
end
