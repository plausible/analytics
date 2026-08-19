defmodule PlausibleWeb.Components.FlowProgress do
  @moduledoc """
  Dotted progress indicator shown in the onboarding layout.
  One small dot per step, with completed and current steps highlighted.
  """
  use Phoenix.Component

  attr :steps, :list, required: true
  attr :current_step, :string, required: true

  def render(assigns) do
    current_step_idx = Enum.find_index(assigns.steps, &(&1 == assigns.current_step))

    assigns = assign(assigns, :current_step_idx, current_step_idx)

    ~H"""
    <div id="flow-progress" class="flex items-center gap-2" aria-label="Progress">
      <span
        :for={{step, idx} <- Enum.with_index(@steps)}
        class={dot_class(dot_state(idx, @current_step_idx))}
        aria-current={idx == @current_step_idx && "step"}
        aria-label={step}
      />
    </div>
    """
  end

  @doc """
  The classnames for a progress dot in the given state. Exposed so tests can
  assert on rendered dots without duplicating the Tailwind classnames.
  """
  def dot_class(:completed), do: "size-2 rounded-full bg-indigo-600 dark:bg-gray-100"
  def dot_class(:current), do: "h-2 w-5 rounded-full bg-indigo-600 dark:bg-gray-100"
  def dot_class(:upcoming), do: "size-2 rounded-full bg-gray-300 dark:bg-gray-600"

  defp dot_state(idx, current_idx) when idx < current_idx, do: :completed
  defp dot_state(idx, current_idx) when idx == current_idx, do: :current
  defp dot_state(_idx, _current_idx), do: :upcoming
end
