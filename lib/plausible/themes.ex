defmodule Plausible.Themes do
  @moduledoc """
  Site light/dark themes definitions.
  """

  @options [
    [key: "Follow System Theme", value: "system"],
    [key: "Light", value: "light"],
    [key: "Dark", value: "dark"]
  ]

  def options() do
    @options
  end
end
