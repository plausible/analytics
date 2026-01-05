defmodule PlausibleWeb.Live.GoalSettings.PropertyPairInput do
  @moduledoc """
  LiveComponent for a property name + value ComboBox pair.

  When a property name is selected, it notifies the value ComboBox
  to update its suggestions based on the selected property.
  """
  use PlausibleWeb, :live_component

  alias PlausibleWeb.Live.Components.ComboBox

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:selected_property, fn -> assigns[:initial_prop_key] end)

    {:ok, socket}
  end

  attr(:site, Plausible.Site)
  attr(:initial_prop_key, :string, default: "")
  attr(:initial_prop_value, :string, default: "")

  def render(assigns) do
    ~H"""
    <div class="flex items-center gap-3" id={@id}>
      <div class="flex-1">
        <.live_component
          id={"#{@id}_key"}
          submit_name="goal[custom_props][keys][]"
          placeholder="Select property"
          module={ComboBox}
          suggest_fun={fn input, _options -> suggest_property_names(@site, input) end}
          selected={if @initial_prop_key != "", do: @initial_prop_key, else: nil}
          on_selection_made={
            fn value, _by_id ->
              send_update(__MODULE__,
                id: @id,
                selected_property: value
              )
            end
          }
          creatable
        />
      </div>

      <span class="text-sm/6 font-medium text-gray-900 dark:text-gray-100">is</span>

      <div class="flex-1">
        <.live_component
          id={"#{@id}_value"}
          submit_name="goal[custom_props][values][]"
          placeholder={if @selected_property, do: "Select value", else: "Select property first"}
          module={ComboBox}
          suggest_fun={
            fn input, _options ->
              suggest_property_values(@site, input, @selected_property)
            end
          }
          selected={if @initial_prop_value != "", do: @initial_prop_value, else: nil}
          options={suggest_property_values(@site, "", @selected_property)}
          creatable
        />
      </div>
    </div>
    """
  end

  defp suggest_property_names(_site, nil), do: []

  defp suggest_property_names(site, input) do
    suggestions = Plausible.Stats.GoalSuggestions.suggest_custom_property_names(site, input)
    Enum.zip(suggestions, suggestions)
  end

  defp suggest_property_values(_site, _, nil), do: []

  defp suggest_property_values(site, input, property_name) do
    suggestions =
      Plausible.Stats.GoalSuggestions.suggest_custom_property_values(site, property_name, input)

    Enum.zip(suggestions, suggestions)
  end
end
