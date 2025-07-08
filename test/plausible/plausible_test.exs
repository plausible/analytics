defmodule PlausibleTest do
  use ExUnit.Case, async: true

  describe "product_name/0" do
    @tag :ce_build_only
    test "returns the correct name in CE" do
      assert Plausible.product_name() == "Stateofweb Analytics"
    end

    @tag :ee_only
    test "returns the correct name in EE" do
      assert Plausible.product_name() == "Stateofweb Analytics"
    end
  end
end
