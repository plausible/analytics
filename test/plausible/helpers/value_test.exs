defmodule Plausible.ValueHelpersTest do
  use Plausible.DataCase
  use Timex

  alias Plausible.ValueHelpers

  describe "validate/2" do
    test "returns prefixed value (with integer id) if it is successfully validated" do
      value = "vendor-123"

      assert ValueHelpers.validate(value, type: :prefixed_id) == value
    end

    test "returns prefixed value (with uuid) if it is successfully validated" do
      value = "vendor-c2b5da86-851a-4aee-ac48-19d6069556c5"

      assert ValueHelpers.validate(value, type: :prefixed_id) == value
    end

    test "returns prefixed value (with multipart prefix and id) if it is successfully validated" do
      value = "other-vendor-prefix-456"

      assert ValueHelpers.validate(value, type: :prefixed_id) == value
    end

    test "returns prefixed value (with multipart prefix and uuid id) if it is successfully validated" do
      value = "other-vendor-prefix-782f008a-b478-4aac-8448-16569a0e4501"

      assert ValueHelpers.validate(value, type: :prefixed_id) == value
    end

    test "returns nil if value does not match predefined pattern (missing id)" do
      value = "vendor"

      refute ValueHelpers.validate(value, type: :prefixed_id)
    end

    test "returns nil if value does not match predefined pattern (wrong id)" do
      value = "vendor-123d"

      refute ValueHelpers.validate(value, type: :prefixed_id)
    end

    test "returns nil if value does not match predefined pattern (wrong uuid)" do
      value = "vendor-abcdefgh123-782f008a-b478-4aac-8448"

      refute ValueHelpers.validate(value, type: :prefixed_id)
    end

    test "returns nil if value does not match predefined pattern (no prefix)" do
      value = "123"

      refute ValueHelpers.validate(value, type: :prefixed_id)
    end
  end
end
