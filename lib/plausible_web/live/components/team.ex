defmodule PlausibleWeb.Live.Components.Team do
  @moduledoc """
  Shared component base for listing team members/invitations
  alongside with the role dropdown.
  """
  use PlausibleWeb, :component
  import PlausibleWeb.Components.Generic

  alias Plausible.Auth.User

  @role_descriptions [
    owner: "Manage the team without restrictions",
    admin: "Manage all team settings",
    editor: "Create and view new sites",
    billing: "Manage subscription",
    viewer: "View all sites under your team"
  ]

  defp role_descriptions, do: @role_descriptions

  @roles_cast_map Enum.into(@role_descriptions, %{}, fn {role, _} -> {to_string(role), role} end)

  def role_to_atom(role), do: Map.fetch!(@roles_cast_map, role)

  attr(:user, User, required: true)
  attr(:label, :string, default: nil)
  attr(:role, :atom, default: nil)
  attr(:my_role, :atom, required: true)
  attr(:me?, :boolean, default: false)
  attr(:disabled, :boolean, default: false)
  attr(:remove_disabled, :boolean, default: false)

  def member(assigns) do
    ~H"""
    <div
      class="mt-6"
      id={"member-row-#{:erlang.phash2(@user.email)}"}
      data-test-kind={if @role == :guest, do: "guest", else: "member"}
      data-role-changed={
        JS.show(
          transition: {"duration-500", "opacity-0 shadow-2xl -translate-y-6", "opacity-100 shadow"},
          time: 400
        )
      }
    >
      <div class="flex items-center gap-x-5">
        <img src={User.profile_img_url(@user)} class="w-8 rounded-full bg-gray-300" />
        <div class="flex flex-col">
          <span class="text-sm font-medium">
            {@user.name}
            <span
              :if={@label}
              class="ml-1 dark:bg-indigo-600 dark:text-gray-200 bg-gray-150 text-gray-500 text-xs px-1 py-0.5 rounded-md"
            >
              {@label}
            </span>
          </span>
          <span class="text-gray-500 text-xs">
            {@user.email}
          </span>
        </div>
        <div class="flex-1 text-right">
          <.dropdown id={"role-dropdown-#{@user.email}"}>
            <:button class="role bg-transparent text-gray-900 dark:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate inline-flex items-center gap-x-2 font-medium rounded-md px-3.5 py-2.5 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700">
              <span :if={@disabled} class="text-gray-400">
                {@role |> to_string() |> String.capitalize()}
              </span>
              <span :if={not @disabled}>
                {@role |> to_string() |> String.capitalize()}
              </span>
              <Heroicons.chevron_down :if={@disabled} mini class="text-gray-400 size-4 mt-0.5" />
              <Heroicons.chevron_down :if={not @disabled} mini class="size-4 mt-0.5" />
            </:button>
            <:menu class="dropdown-items max-w-60">
              <.role_item
                :for={{role, description} <- role_descriptions()}
                user={@user}
                id={"option-#{:erlang.phash2(@user.email)}-#{role}"}
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={role}
                disabled={@disabled or @role == role}
                dispatch_animation?={@role == :guest}
                data-confirm={
                  if @me? and role in [:editor, :billing, :viewer], do: lower_role_warning()
                }
              >
                {description}
              </.role_item>
              <.dropdown_divider />

              <.dropdown_item
                id={"#{:erlang.phash2(@user.email)}-remove"}
                href="#"
                disabled={@disabled or @remove_disabled}
                phx-click="remove-member"
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                data-confirm="Are you sure you want to remove this member from the team?"
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

  attr(:id, :string, required: true)
  attr(:role, :atom, required: true)
  attr(:my_role, :atom, required: true)
  attr(:rest, :global)

  def role_picker(assigns) do
    ~H"""
    <.dropdown id={@id}>
      <:button class="role w-[100px] inline-flex items-center justify-between font-medium rounded-md px-3 py-2 text-sm border border-gray-300 dark:border-gray-750 rounded-md text-gray-800 dark:text-gray-100 dark:bg-gray-750 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate shadow-xs hover:shadow-sm transition-all duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700">
        {@role |> Atom.to_string() |> String.capitalize()}
        <Heroicons.chevron_down mini class="size-4 mt-0.5" />
      </:button>
      <:menu class="dropdown-items max-w-60">
        <.role_item
          :for={{role, description} <- role_descriptions()}
          role={role}
          disabled={role_change_disabled?(@my_role, role)}
          {@rest}
        >
          {description}
        </.role_item>
      </:menu>
    </.dropdown>
    """
  end

  attr(:role, :atom, required: true)
  attr(:disabled, :boolean, default: false)
  attr(:dispatch_animation?, :boolean, default: false)
  attr(:rest, :global)
  attr(:user, :map, default: %{email: nil})
  attr(:id, :string, default: nil)

  slot(:inner_block, required: true)

  def role_item(assigns) do
    click =
      cond do
        phx_click = assigns.rest[:"phx-click"] ->
          phx_click

        assigns.dispatch_animation? ->
          JS.hide(
            transition: {"duration-500", "opacity-100", "opacity-0"},
            to: "#member-row-#{:erlang.phash2(assigns.user.email)}",
            time: 500
          )
          |> JS.push("update-role")

        true ->
          "update-role"
      end

    assigns = assign(assigns, :click, click)

    ~H"""
    <.dropdown_item
      id={@id}
      href="#"
      phx-click={@click}
      phx-value-role={@role}
      disabled={@disabled}
      {@rest}
    >
      <div>{@role |> Atom.to_string() |> String.capitalize()}</div>
      <div class="text-gray-500 dark:text-gray-400 text-xs/5">
        {render_slot(@inner_block)}
      </div>
    </.dropdown_item>
    """
  end

  defp role_change_disabled?(my_role, :owner), do: my_role != :owner
  defp role_change_disabled?(my_role, _role), do: my_role not in [:owner, :admin]

  defp lower_role_warning() do
    "You're about to lower your own role. Some team management features will no longer be accessible to you, and you'll need to ask a team owner to restore your access. Do you want to continue?"
  end
end
