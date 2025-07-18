defmodule Plausible.Themes do
  @options [
    [key: "System-Theme folgen", value: "system"],
    [key: "Hell", value: "light"],
    [key: "Dunkel", value: "dark"]
  ]

  def options() do
    @options
  end
end
