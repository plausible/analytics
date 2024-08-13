defmodule PlausibleWeb.DebugView do
  use PlausibleWeb, :view

  def controller_name(phoenix_controller_name) do
    phoenix_controller_name
    |> String.to_existing_atom()
    |> Module.split()
    |> Enum.drop_while(&String.starts_with?(&1, "Plausible"))
    |> Enum.join(".")
  end
end
