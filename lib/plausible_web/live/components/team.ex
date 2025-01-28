defmodule PlausibleWeb.Live.Components.Team do
  @moduledoc """
  Shared component base for listing team members/invitations
  alongside with the role dropdown.
  """
  use Phoenix.Component
  import PlausibleWeb.Components.Generic
  alias Plausible.Auth.User

  attr :user, User, required: true
  attr :label, :string, default: nil
  attr :role, :atom, default: nil
  attr :my_role, :atom, required: true
  attr :disabled, :boolean, default: false
  attr :remove_disabled, :boolean, default: false

  def member(assigns) do
    ~H"""
    <div class="member mt-4">
      <div class="flex items-center gap-x-5">
        <img src={User.profile_img_url(@user)} class="w-7 rounded-full" />
        <span class="text-sm">
          {@user.name}
          <span
            :if={@label}
            class="ml-1 dark:bg-indigo-600 dark:text-gray-200 bg-gray-100 text-gray-500 text-xs px-1 rounded"
          >
            {@label}
          </span>

          <br /><span class="text-gray-500 text-xs">{@user.email}</span>
        </span>
        <div class="flex-1 text-right">
          <.dropdown class="relative">
            <:button class="role bg-transparent text-gray-800 dark:text-gray-100 hover:bg-gray-50 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate inline-flex items-center gap-x-2 font-medium rounded-md px-3.5 py-2.5 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700">
              {@role |> to_string() |> String.capitalize()}
              <Heroicons.chevron_down mini class="size-4 mt-0.5" />
            </:button>
            <:menu class="dropdown-items max-w-60">
              <.role_item
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={:owner}
                disabled={@disabled or @role == :owner}
                phx-click="update-role"
              >
                Manage the team without restrictions
              </.role_item>
              <.role_item
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={:admin}
                disabled={@disabled or @role == :admin}
                phx-click="update-role"
              >
                Manage all team settings
              </.role_item>
              <.role_item
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={:editor}
                disabled={@disabled or @role == :editor}
                phx-click="update-role"
              >
                Create and view new sites
              </.role_item>
              <.role_item
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={:billing}
                disabled={@disabled or @role == :billing}
                phx-click="update-role"
              >
                Manage subscription
              </.role_item>
              <.role_item
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={:viewer}
                disabled={@disabled or @role == :viewer}
                phx-click="update-role"
              >
                View all sites under your team
              </.role_item>
              <.dropdown_divider />
              <.dropdown_item
                href="#"
                disabled={@disabled or @remove_disabled}
                phx-click="remove-member"
                phx-value-email={@user.email}
                phx-value-name={@user.name}
              >
                <div class={
                  not @remove_disabled &&
                    "text-red-600 hover:text-red-600 dark:text-red-500 hover:dark:text-red-400"
                }>
                  Remove member
                </div>
                <div class="text-gray-500 dark:text-gray-400 text-xs/5">
                  Remove member from your team
                </div>
              </.dropdown_item>
            </:menu>
          </.dropdown>
        </div>
      </div>
    </div>
    """
  end

  attr :role, :atom, required: true
  attr :disabled, :boolean, default: false
  slot :inner_block, required: true
  attr :rest, :global

  def role_item(assigns) do
    ~H"""
    <.dropdown_item href="#" phx-value-role={@role} disabled={@disabled} {@rest}>
      <div>{@role |> Atom.to_string() |> String.capitalize()}</div>
      <div class="text-gray-500 dark:text-gray-400 text-xs/5">
        {render_slot(@inner_block)}
      </div>
    </.dropdown_item>
    """
  end
end
