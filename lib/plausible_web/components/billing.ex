defmodule PlausibleWeb.Components.Billing do
  @moduledoc false

  use Phoenix.Component

  slot(:inner_block, required: true)
  attr(:rest, :global)

  def usage_and_limits_table(assigns) do
    ~H"""
    <table class="min-w-full text-gray-900 dark:text-gray-100" {@rest}>
      <tbody class="divide-y divide-gray-200 dark:divide-gray-600">
        <%= render_slot(@inner_block) %>
      </tbody>
    </table>
    """
  end

  attr(:title, :string, required: true)
  attr(:usage, :any, required: true)
  attr(:limit, :integer, default: nil)
  attr(:pad, :boolean, default: false)
  attr(:rest, :global)

  def usage_and_limits_row(assigns) do
    ~H"""
    <tr {@rest}>
      <td class={["py-4 text-sm whitespace-nowrap text-left", @pad && "pl-6"]}><%= @title %></td>
      <td class="py-4 text-sm whitespace-nowrap text-right">
        <%= Cldr.Number.to_string!(@usage) %>
        <%= if is_number(@limit), do: "/ #{Cldr.Number.to_string!(@limit)}" %>
      </td>
    </tr>
    """
  end
end
