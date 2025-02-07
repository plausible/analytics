defmodule PlausibleWeb.Storybook.Input do
  @moduledoc false
  use PhoenixStorybook.Story, :component

  def function, do: &PlausibleWeb.Live.Components.Form.input/1

  def attributes, do: []
  def slots, do: []

  def variations do
    [
      %Variation{
        id: :default,
        description: "Basic input",
        attributes: %{
          name: "user[name]",
          value: "",
          label: "Full name"
        }
      },
      %Variation{
        id: :errors,
        description: "With help text and error",
        attributes: %{
          name: "user[name]",
          value: "",
          label: "Email",
          help_text: "Get ready for spam!",
          errors: ["Cannot be blank"]
        }
      },
      %Variation{
        id: :select,
        description: "Select input",
        attributes: %{
          name: "user[color_mode]",
          value: "System",
          label: "Color mode",
          type: "select",
          options: ["System", "Light", "Dark"]
        }
      }
    ]
  end
end
