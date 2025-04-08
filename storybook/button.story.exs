defmodule PlausibleWeb.Storybook.Button do
  @moduledoc false
  use PhoenixStorybook.Story, :component

  def function, do: &PlausibleWeb.Components.Generic.button/1

  def attributes, do: []
  def slots, do: []

  def variations do
    [
      %Variation{
        id: :default,
        description: "Primary button",
        slots: ["Click me!"]
      },
      %Variation{
        id: :disabled,
        description: "Disabled button",
        attributes: %{
          "disabled" => "true"
        },
        slots: ["Click me!"]
      },
      %Variation{
        id: :bright,
        description: "Bright button",
        attributes: %{
          "theme" => "bright"
        },
        slots: ["Click me!"]
      },
      %Variation{
        id: :danger,
        description: "Danger button",
        attributes: %{
          "theme" => "danger"
        },
        slots: ["Click me!"]
      }
    ]
  end
end
