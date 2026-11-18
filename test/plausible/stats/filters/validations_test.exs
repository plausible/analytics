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

  describe "validate_toplevel_only/1" do
    for dimension <- ["event:goal", "event:hostname"] do
      test "accepts #{dimension} at the top level" do
        assert Filters.Validations.validate_toplevel_only([
                 [:is, unquote(dimension), ["foo"]]
               ]) == :ok
      end

      for operator <- [:and, :or] do
        test "rejects #{dimension} inside #{operator}" do
          assert {:error, %QueryError{code: :invalid_filters, message: message}} =
                   Filters.Validations.validate_toplevel_only([
                     [
                       unquote(operator),
                       [[:is, unquote(dimension), ["foo"]], [:is, "visit:source", ["Bing"]]]
                     ]
                   ])

          assert message ==
                   "Invalid filters. Dimension `#{unquote(dimension)}` can only be filtered at the top level."
        end
      end

      test "rejects #{dimension} inside not" do
        assert {:error, %QueryError{code: :invalid_filters}} =
                 Filters.Validations.validate_toplevel_only([
                   [:not, [:is, unquote(dimension), ["foo"]]]
                 ])
      end

      for operator <- [:has_done, :has_not_done] do
        test "accepts #{dimension} inside #{operator}" do
          assert Filters.Validations.validate_toplevel_only([
                   [unquote(operator), [:is, unquote(dimension), ["foo"]]]
                 ]) == :ok
        end
      end
    end

    test "accepts other dimensions at any depth" do
      assert Filters.Validations.validate_toplevel_only([
               [:not, [:or, [[:is, "event:page", ["/a"]], [:is, "visit:source", ["Bing"]]]]]
             ]) == :ok
    end
  end

  describe "validate_behavioral/1" do
    for operator <- [:has_done, :has_not_done] do
      for prop <- Filters.event_props() do
        test "accepts #{operator} with an event:#{prop} filter" do
          assert Filters.Validations.validate_behavioral([
                   [unquote(operator), [:is, "event:#{unquote(prop)}", ["foo"]]]
                 ]) == :ok
        end
      end

      test "accepts #{operator} with a tree of event dimension filters" do
        assert Filters.Validations.validate_behavioral([
                 [
                   unquote(operator),
                   [:or, [[:is, "event:name", ["Signup"]], [:is, "event:page", ["/a"]]]]
                 ]
               ]) == :ok
      end

      test "rejects #{operator} with a visit dimension filter" do
        assert {:error, %QueryError{code: :invalid_filters, message: message}} =
                 Filters.Validations.validate_behavioral([
                   [unquote(operator), [:is, "visit:source", ["Bing"]]]
                 ])

        assert message ==
                 "Invalid filters. Behavioral filters (has_done, has_not_done) can only be used with event dimension filters."
      end
    end

    test "rejects nested behavioral filters" do
      assert {:error, %QueryError{code: :invalid_filters, message: message}} =
               Filters.Validations.validate_behavioral([
                 [:has_done, [:has_not_done, [:is, "event:name", ["Signup"]]]]
               ])

      assert message ==
               "Invalid filters. Behavioral filters (has_done, has_not_done) cannot be nested."
    end

    test "allows non-behavioral filters" do
      assert Filters.Validations.validate_behavioral([
               [:is, "visit:source", ["Bing"]],
               [:not, [:is, "visit:country", ["EE"]]]
             ]) == :ok
    end
  end

  describe "validate_custom_props_access/2" do
    test "accepts any custom property when all are allowed" do
      assert Filters.Validations.validate_custom_props_access(
               [[:is, "event:props:author", ["John"]]],
               :all
             ) == :ok
    end

    test "accepts an allowed custom property" do
      assert Filters.Validations.validate_custom_props_access(
               [[:is, "event:props:author", ["John"]]],
               ["author"]
             ) == :ok
    end

    test "rejects a custom property that is not allowed" do
      assert Filters.Validations.validate_custom_props_access(
               [[:is, "event:props:author", ["John"]]],
               ["theme"]
             ) == {:error, Filters.Validations.custom_props_access_error()}
    end

    test "rejects a nested custom property that is not allowed" do
      assert {:error, %QueryError{code: :feature_access}} =
               Filters.Validations.validate_custom_props_access(
                 [
                   [
                     :or,
                     [[:is, "visit:source", ["Bing"]], [:is, "event:props:author", ["John"]]]
                   ]
                 ],
                 ["theme"]
               )
    end

    test "accepts filters without custom properties" do
      assert Filters.Validations.validate_custom_props_access(
               [[:is, "visit:source", ["Bing"]]],
               []
             ) == :ok
    end
  end
end
