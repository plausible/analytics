defmodule Plausible.Stats.JSONSchema.UtilsTest do
  use ExUnit.Case, async: true

  alias Plausible.Stats.JSONSchema

  describe "traversing" do
    test "transform 'fn value -> value end' does not drop anything" do
      json = %{foo: %{bar: [0, ""], baz: nil, pax: %{}}}
      assert JSONSchema.Utils.traverse(json, fn value -> value end) == json
    end

    test "can remove specific items, keeping the original order of lists" do
      assert JSONSchema.Utils.traverse(
               %{
                 foo: [
                   "a",
                   %{type: "string", "$comment": "only :internal"},
                   %{type: "number"}
                 ]
               },
               fn
                 %{"$comment": "only :internal"} -> :remove
                 value -> value
               end
             ) == %{foo: ["a", %{type: "number"}]}
    end

    test "can transform specific items" do
      assert JSONSchema.Utils.traverse(
               %{
                 foo: [
                   %{type: "string", "$comment": "anything"},
                   %{type: "number"}
                 ]
               },
               fn
                 %{"$comment": "anything"} -> %{type: "number", "$comment": "transformed"}
                 value -> value
               end
             ) == %{foo: [%{type: "number", "$comment": "transformed"}, %{type: "number"}]}
    end
  end
end
