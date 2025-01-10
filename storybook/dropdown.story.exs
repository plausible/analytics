defmodule PlausibleWeb.Storybook.Dropdown do
  @moduledoc false
  use PhoenixStorybook.Story, :component

  # required
  def function, do: &PlausibleWeb.Components.Generic.dropdown/1
  def imports, do: [{PlausibleWeb.Components.Generic, dropdown_item: 1, dropdown_divider: 1}]

  def attributes, do: []
  def slots, do: []

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default dropdown",
        slots: [
          ~s|
<:button class="bg-transparent text-gray-800 dark:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate inline-flex items-center gap-x-2 font-medium rounded-md px-3.5 py-2.5 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">Click me</:button>
<:menu>
  <.dropdown_item href="#">Option A</.dropdown_item>
  <.dropdown_item href="#">Option B</.dropdown_item>
  <.dropdown_divider />
  <.dropdown_item href="#" class="text-red-600 dark:text-red-600">Nuclear option</.dropdown_item>
</:menu>
|
        ]
      }
    ]
  end
end
