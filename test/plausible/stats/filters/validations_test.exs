defmodule Plausible.Stats.Filters.ValidationsTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.{Filters, QueryError}

  describe "validate_case_sensitive_modifier/1" do
    for operation <- [
          :is,
          :is_not,
          :matches_wildcard,
          :matches_wildcard_not,
          :matches,
          :matches_not,
          :contains,
          :contains_not
        ] do
      test "accepts a simple #{operation} filter without the modifier" do
        assert Filters.Validations.validate_case_sensitive_modifier([
                 [unquote(operation), "event:name", ["foo"]]
               ]) == :ok
      end

      test "accepts a nested #{operation} filter without the modifier" do
        assert Filters.Validations.validate_case_sensitive_modifier([
                 [
                   :not,
                   [
                     :and,
                     [
                       [unquote(operation), "event:name", ["foo"]],
                       [unquote(operation), "event:name", ["bar"]]
                     ]
                   ]
                 ]
               ]) == :ok
      end
    end

    for operation <- [:is, :is_not, :contains, :contains_not] do
      test "accepts the case_sensitive modifier with #{operation}" do
        assert Filters.Validations.validate_case_sensitive_modifier([
                 [unquote(operation), "event:page", ["a"], %{case_sensitive: false}]
               ]) == :ok
      end
    end

    for operation <- [:matches, :matches_not, :matches_wildcard, :matches_wildcard_not] do
      test "case_sensitive modifier is not valid for #{operation}" do
        assert {:error, %QueryError{message: error}} =
                 Filters.Validations.validate_case_sensitive_modifier([
                   [unquote(operation), "event:page", ["a"], %{case_sensitive: false}]
                 ])

        assert error =~ "Invalid filters."
        assert error =~ "case_sensitive modifier is not allowed with pattern operators"
        assert error =~ Atom.to_string(unquote(operation))
      end
    end

    test "prohibits case_sensitive modifier with pattern operator in a complex filter tree" do
      assert {:error, %QueryError{message: error}} =
               Filters.Validations.validate_case_sensitive_modifier([
                 [
                   :or,
                   [
                     [
                       :and,
                       [
                         [:is, "visit:city_name", ["London"]],
                         [:not, [:is, "visit:country_name", ["Canada"]]]
                       ]
                     ],
                     [:matches, "event:page", ["a"], %{case_sensitive: false}]
                   ]
                 ]
               ])

      assert error =~ "Invalid filters."
      assert error =~ "case_sensitive modifier is not allowed with pattern operators"
      assert error =~ ":matches"
    end
  end
end
