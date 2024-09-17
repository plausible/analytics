defmodule Plausible.Stats.JSONSchemaToolsTest do
  use ExUnit.Case, async: true

  alias Plausible.Stats.JSONSchemaTools

  describe "traversing" do
    test "transform 'fn value -> value end' does not drop anything" do
      json = %{foo: %{bar: [0, ""], baz: nil, pax: %{}}}
      assert JSONSchemaTools.traverse(json, fn value -> value end) == json
    end

    test "can remove specific items" do
      assert JSONSchemaTools.traverse(
               %{
                 foo: [
                   "a",
                   %{type: "string", "$comment": "private"},
                   %{type: "number"}
                 ]
               },
               fn
                 %{"$comment": "private"} -> :remove
                 value -> value
               end
             ) == %{foo: ["a", %{type: "number"}]}
    end

    test "can transform specific items" do
      assert JSONSchemaTools.traverse(
               %{
                 foo: [
                   %{type: "string", "$comment": "private"},
                   %{type: "number"}
                 ]
               },
               fn
                 %{"$comment": "private"} -> %{type: "number", "$comment": "transformed"}
                 value -> value
               end
             ) == %{foo: [%{type: "number", "$comment": "transformed"}, %{type: "number"}]}
    end
  end
end
