defmodule Plausible.Themes do
  @moduledoc "https://stackoverflow.com/a/52265733"

  @options [
    [key: "Follow System Theme", value: "system"],
    [key: "Light", value: "light"],
    [key: "Dark", value: "dark"]
  ]

  def options() do
    @options
  end
end
