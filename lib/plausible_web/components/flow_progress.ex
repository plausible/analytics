defmodule PlausibleWeb.Components.FlowProgress do
  @moduledoc """
  Component for provisioning/registration flows displaying
  progress status.
  """
  use Phoenix.Component

  @flows %{
    "review" => [
      "Install Plausible",
      "Verify installation"
    ],
    "domain_change" => [
      "Set up new domain",
      "Install Plausible",
      "Verify installation"
    ],
    "register" => [
      "Register",
      "Activate account",
      "Add site info",
      "Install Plausible",
      "Verify installation"
    ],
    "invitation" => [
      "Register",
      "Activate account"
    ],
    "provisioning" => [
      "Add site info",
      "Install Plausible",
      "Verify installation"
    ]
  }

  @values @flows |> Enum.flat_map(fn {_, steps} -> steps end) |> Enum.uniq()

  def flows, do: @flows

  attr :flow, :string, required: true
  attr :current_step, :string, required: true, values: @values

  def render(assigns) do
    steps = Map.get(flows(), assigns.flow, [])
    current_step_idx = Enum.find_index(steps, &(&1 == assigns.current_step))

    assigns =
      assign(assigns,
        steps: steps,
        current_step_idx: current_step_idx
      )

    ~H"""
    <div :if={not Enum.empty?(@steps)} class="mt-6 hidden md:block" id="flow-progress">
      <div class="flex items-center justify-between max-w-3xl mx-auto my-8">
        <%= for {step, idx} <- Enum.with_index(@steps) do %>
          <div class="flex items-center text-xs">
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
              <%= idx + 1 %>
            </div>
            <div
              :if={idx > @current_step_idx}
              class="w-5 h-5 bg-gray-300 text-white dark:bg-gray-800 rounded-full flex items-center justify-center"
            >
              <%= idx + 1 %>
            </div>
            <span :if={idx < @current_step_idx} class="ml-2 text-gray-500">
              <%= step %>
            </span>
            <span
              :if={idx == @current_step_idx}
              class="ml-2 font-semibold text-black dark:text-gray-300"
            >
              <%= step %>
            </span>
            <span :if={idx > @current_step_idx} class="ml-2 text-gray-500">
              <%= step %>
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
