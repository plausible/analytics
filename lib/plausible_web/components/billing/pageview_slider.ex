defmodule PlausibleWeb.Components.Billing.PageviewSlider do
  @moduledoc false

  use PlausibleWeb, :component

  def render(assigns) do
    ~H"""
    <.slider_output volume={@selected_volume} available_volumes={@available_volumes} />
    <.slider_input selected_volume={@selected_volume} available_volumes={@available_volumes} />
    <.slider_styles />
    """
  end

  attr :volume, :any
  attr :available_volumes, :list

  defp slider_output(assigns) do
    ~H"""
    <output class="lg:w-1/4 lg:order-1 font-medium text-lg text-gray-600 dark:text-gray-200">
      <span :if={@volume != :enterprise}>Up to</span>
      <strong id="slider-value" class="text-gray-900 dark:text-gray-100">
        {format_volume(@volume, @available_volumes)}
      </strong>
      monthly pageviews
    </output>
    """
  end

  defp slider_input(assigns) do
    slider_labels =
      Enum.map(
        assigns.available_volumes ++ [:enterprise],
        &format_volume(&1, assigns.available_volumes)
      )

    assigns = assign(assigns, :slider_labels, slider_labels)

    ~H"""
    <form class="max-w-md lg:max-w-none w-full lg:w-1/2 lg:order-2">
      <div class="flex items-baseline space-x-2">
        <span class="text-xs font-medium text-gray-600 dark:text-gray-200">
          {List.first(@slider_labels)}
        </span>
        <div class="flex-1 relative">
          <input
            phx-change="slide"
            id="slider"
            name="slider"
            class="shadow mt-8 dark:bg-gray-600 dark:border-none"
            type="range"
            min="0"
            max={length(@available_volumes)}
            step="1"
            value={
              Enum.find_index(@available_volumes, &(&1 == @selected_volume)) ||
                length(@available_volumes)
            }
            oninput="repositionBubble()"
          />
          <output
            id="slider-bubble"
            class="absolute bottom-[35px] py-[4px] px-[12px] -translate-x-1/2 rounded-md text-white bg-indigo-600 position text-xs font-medium"
            phx-update="ignore"
          />
        </div>
        <span class="text-xs font-medium text-gray-600 dark:text-gray-200">
          {List.last(@slider_labels)}
        </span>
      </div>
    </form>

    <script>
      const SLIDER_LABELS = <%= Phoenix.HTML.raw Jason.encode!(@slider_labels) %>

      function repositionBubble() {
        const input = document.getElementById("slider")
        const percentage = Number((input.value / input.max) * 100)
        const bubble = document.getElementById("slider-bubble")

        bubble.innerHTML = SLIDER_LABELS[input.value]
        bubble.style.left = `calc(${percentage}% + (${13.87 - percentage * 0.26}px))`
      }

      repositionBubble()
    </script>
    """
  end

  defp format_volume(volume, available_volumes) do
    if volume == :enterprise do
      available_volumes
      |> List.last()
      |> PlausibleWeb.StatsView.large_number_format()
      |> Kernel.<>("+")
    else
      PlausibleWeb.StatsView.large_number_format(volume)
    end
  end

  defp slider_styles(assigns) do
    ~H"""
    <style>
      input[type="range"] {
        -moz-appearance: none;
        -webkit-appearance: none;
        background: white;
        border-radius: 3px;
        height: 6px;
        width: 100%;
        margin-bottom: 9px;
        outline: none;
      }

      input[type="range"]::-webkit-slider-thumb {
        appearance: none;
        -webkit-appearance: none;
        background-color: #5f48ff;
        background-image: url("data:image/svg+xml;charset=US-ASCII,%3Csvg%20width%3D%2212%22%20height%3D%228%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M8%20.5v7L12%204zM0%204l4%203.5v-7z%22%20fill%3D%22%23FFFFFF%22%20fill-rule%3D%22nonzero%22%2F%3E%3C%2Fsvg%3E");
        background-position: center;
        background-repeat: no-repeat;
        border: 0;
        border-radius: 50%;
        cursor: pointer;
        height: 26px;
        width: 26px;
      }

      input[type="range"]::-moz-range-thumb {
        background-color: #5f48ff;
        background-image: url("data:image/svg+xml;charset=US-ASCII,%3Csvg%20width%3D%2212%22%20height%3D%228%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M8%20.5v7L12%204zM0%204l4%203.5v-7z%22%20fill%3D%22%23FFFFFF%22%20fill-rule%3D%22nonzero%22%2F%3E%3C%2Fsvg%3E");
        background-position: center;
        background-repeat: no-repeat;
        border: 0;
        border: none;
        border-radius: 50%;
        cursor: pointer;
        height: 26px;
        width: 26px;
      }

      input[type="range"]::-ms-thumb {
        background-color: #5f48ff;
        background-image: url("data:image/svg+xml;charset=US-ASCII,%3Csvg%20width%3D%2212%22%20height%3D%228%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M8%20.5v7L12%204zM0%204l4%203.5v-7z%22%20fill%3D%22%23FFFFFF%22%20fill-rule%3D%22nonzero%22%2F%3E%3C%2Fsvg%3E");
        background-position: center;
        background-repeat: no-repeat;
        border: 0;
        border-radius: 50%;
        cursor: pointer;
        height: 26px;
        width: 26px;
      }

      input[type="range"]::-moz-focus-outer {
        border: 0;
      }
    </style>
    """
  end
end
