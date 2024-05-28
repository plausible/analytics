defmodule PlausibleTest do
  use ExUnit.Case, async: true

  describe "product_name/0" do
    @tag :ce_build_only
    test "returns the correct name in CE" do
      assert Plausible.product_name() == "Plausible CE"
    end

    @tag :ee_only
    test "returns the correct name in EE" do
      assert Plausible.product_name() == "Plausible Analytics"
    end
  end
end
