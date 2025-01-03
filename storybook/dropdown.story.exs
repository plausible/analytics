defmodule MyAppWeb.Storybook.MyComponent do
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
<:button class="bg-white dark:bg-gray-300 text-gray-800 hover:bg-gray-50 focus-visible:outline-gray-100 whitespace-nowrap truncate inline-flex items-center gap-x-2 font-medium rounded-md px-3.5 py-2.5 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700">Click me</:button>
<:menu>
  <.dropdown_item href="#">Option A</.dropdown_item>
  <.dropdown_item href="#">Option B</.dropdown_item>
  <.dropdown_divider />
  <.dropdown_item href="#" class="text-red-600">Nuclear option</.dropdown_item>
</:menu>
|
        ]
      }
    ]
  end
end
