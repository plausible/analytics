defmodule PlausibleWeb.Components.Dashboard.ImportedDataWarnings do
  @moduledoc false

  use PlausibleWeb, :component
  alias Plausible.Stats.QueryResult

  def unsupported_filters(assigns) do
    show? =
      case assigns.query_result do
        %QueryResult{meta: meta} ->
          meta[:imports_skip_reason] == :unsupported_query

        _ ->
          false
      end

    assigns = assign(assigns, :show?, show?)

    ~H"""
    <div :if={@show?} data-test-id="unsupported-filters-warning">
      <span class="hidden">
        Imported data is excluded due to the applied filters
      </span>
      <Heroicons.exclamation_circle class="mb-1 size-4.5 text-gray-500 dark:text-gray-400" />
    </div>
    """
  end
end
