defmodule PlausibleWeb.Components.FlowProgress do
  @moduledoc """
  Dotted progress indicator shown during the registration flow.
  One small dot per step in `PlausibleWeb.Flows.steps/1`, with completed
  and current steps highlighted.
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
    <div
      :if={not Enum.empty?(@steps)}
      id="flow-progress"
      class="flex items-center gap-2"
      aria-label="Progress"
    >
      <span
        :for={{step, idx} <- Enum.with_index(@steps)}
        class={
          cond do
            idx == @current_step_idx -> "h-2 w-5 rounded-full bg-indigo-600 dark:bg-gray-100"
            idx < @current_step_idx -> "size-2 rounded-full bg-indigo-600 dark:bg-gray-100"
            true -> "size-2 rounded-full bg-gray-300 dark:bg-gray-600"
          end
        }
        aria-current={idx == @current_step_idx && "step"}
        aria-label={step}
      />
    </div>
    """
  end
end
