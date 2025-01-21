defmodule PlausibleWeb.Components.FlowProgress do
  @moduledoc """
  Component for provisioning/registration flows displaying
  progress status. See `PlausibleWeb.Flows` for the list of
  flow definitions.
  """
  use Phoenix.Component

  attr :flow, :string, required: true, values: PlausibleWeb.Flows.valid_keys()
  attr :current_step, :string, required: true, values: PlausibleWeb.Flows.valid_values()

  def render(assigns) do
    steps = PlausibleWeb.Flows.steps(assigns.flow)
    current_step_idx = Enum.find_index(steps, &(&1 == assigns.current_step))

    assigns =
      assign(assigns,
        steps: steps,
        current_step_idx: current_step_idx
      )

    ~H"""
    <div :if={not Enum.empty?(@steps)} class="mt-6 hidden md:block" id="flow-progress">
      <div class="flex items-center justify-between max-w-4xl mx-auto my-8">
        <%= for {step, idx} <- Enum.with_index(@steps) do %>
          <div class="flex items-center text-base">
            <div
              :if={idx < @current_step_idx}
              class="w-5 h-5 bg-green-500 dark:bg-green-600 text-white rounded-full flex items-center justify-center"
            >
              <Heroicons.check class="w-4 h-4" />
            </div>
            <div
              :if={idx == @current_step_idx}
              class="w-5 h-5 bg-indigo-600 text-white rounded-full flex items-center justify-center font-semibold"
            >
              {idx + 1}
            </div>
            <div
              :if={idx > @current_step_idx}
              class="w-5 h-5 bg-gray-300 text-white dark:bg-gray-800 rounded-full flex items-center justify-center"
            >
              {idx + 1}
            </div>
            <span :if={idx < @current_step_idx} class="ml-2 text-gray-500">
              {step}
            </span>
            <span
              :if={idx == @current_step_idx}
              class="ml-2 font-semibold text-black dark:text-gray-300"
            >
              {step}
            </span>
            <span :if={idx > @current_step_idx} class="ml-2 text-gray-500">
              {step}
            </span>
          </div>
          <div :if={idx + 1 != length(@steps)} class="flex-1 h-px bg-gray-300 mx-4 dark:bg-gray-800 ">
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
