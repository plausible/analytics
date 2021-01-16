defmodule Plausible.Themes do
  @options [
    [key: "Follow System Theme", value: "system"],
    [key: "Light", value: "light"],
    [key: "Dark", value: "dark"]
  ]

  def options() do
    @options
  end
end
