defmodule PlausibleWeb.Live.Components.Team do
  @moduledoc """
  Shared component base for listing team members/invitations
  alongside with the role dropdown.
  """
  use PlausibleWeb, :component
  import PlausibleWeb.Components.Generic

  alias Plausible.Auth.User

  attr(:user, User, required: true)
  attr(:label, :string, default: nil)
  attr(:role, :atom, default: nil)
  attr(:my_role, :atom, required: true)
  attr(:disabled, :boolean, default: false)
  attr(:remove_disabled, :boolean, default: false)

  def member(assigns) do
    ~H"""
    <div
      class="mt-4"
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
        <img src={User.profile_img_url(@user)} class="w-7 rounded-full bg-gray-300" />
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
          <.dropdown id={"role-dropdown-#{@user.email}"}>
            <:button class="role bg-transparent text-gray-800 dark:text-gray-100 hover:bg-gray-50 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate inline-flex items-center gap-x-2 font-medium rounded-md px-3.5 py-2.5 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700">
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
                user={@user}
                id={"option-#{:erlang.phash2(@user.email)}-owner"}
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={:owner}
                disabled={@disabled or @role == :owner}
                dispatch_animation?={@role == :guest}
              >
                Manage the team without restrictions
              </.role_item>
              <.role_item
                user={@user}
                id={"option-#{:erlang.phash2(@user.email)}-admin"}
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={:admin}
                disabled={@disabled or @role == :admin}
                dispatch_animation?={@role == :guest}
              >
                Manage all team settings
              </.role_item>
              <.role_item
                user={@user}
                id={"option-#{:erlang.phash2(@user.email)}-editor"}
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={:editor}
                disabled={@disabled or @role == :editor}
                dispatch_animation?={@role == :guest}
              >
                Create and view new sites
              </.role_item>
              <.role_item
                user={@user}
                id={"option-#{:erlang.phash2(@user.email)}-billing"}
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={:billing}
                disabled={@disabled or @role == :billing}
                dispatch_animation?={@role == :guest}
              >
                Manage subscription
              </.role_item>
              <.role_item
                user={@user}
                id={"option-#{:erlang.phash2(@user.email)}-viewer"}
                phx-value-email={@user.email}
                phx-value-name={@user.name}
                role={:viewer}
                disabled={@disabled or @role == :viewer}
                dispatch_animation?={@role == :guest}
              >
                View all sites under your team
              </.role_item>
              <.dropdown_divider />

              <.dropdown_item
                id={"#{:erlang.phash2(@user.email)}-remove"}
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
end
