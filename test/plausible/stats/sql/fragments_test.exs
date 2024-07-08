defmodule Plausible.Stats.SQL.FragmentsTest do
  use ExUnit.Case, async: true
  use Plausible.Stats.SQL.Fragments

  defmacro expand_macro_once(ast) do
    ast |> Macro.expand_once(__ENV__) |> Macro.to_string()
  end

  doctest Plausible.Stats.SQL.Fragments
end
