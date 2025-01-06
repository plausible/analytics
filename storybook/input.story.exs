defmodule MyAppWeb.Storybook.Input do
  use PhoenixStorybook.Story, :component

  # required
  def function, do: &PlausibleWeb.Live.Components.Form.input/1
  # def imports, do: [{PlausibleWeb.Components.Generic, dropdown_item: 1, dropdown_divider: 1}]

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
        id: :help_text,
        description: "With help text",
        attributes: %{
          name: "user[name]",
          value: "",
          label: "Email",
          help_text: "Get ready for spam!"
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
      }
    ]
  end
end
