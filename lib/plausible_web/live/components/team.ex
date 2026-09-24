defmodule PlausibleWeb.Live.Components.Team do
  @moduledoc """
  Shared component base for listing team members/invitations
  alongside with the role dropdown.
  """
  use PlausibleWeb, :component
  import PlausibleWeb.Components.Generic

  alias Plausible.Auth.User
  alias PlausibleWeb.Components.PrimaListbox

  @role_descriptions [
    owner: "Manage the team without restrictions",
    admin: "Manage all team settings",
    editor: "Create and view new sites",
    billing: "Manage subscription",
    viewer: "View all sites under your team"
  ]

  def role_descriptions, do: @role_descriptions

  @roles_cast_map Enum.into(@role_descriptions, %{}, fn {role, _} -> {to_string(role), role} end)

  def role_to_atom(role), do: Map.fetch!(@roles_cast_map, role)

  defp role_to_capitalized_string(role) when is_atom(role) do
    role |> Atom.to_string() |> String.capitalize()
  end

  attr(:user, User, required: true)
  attr(:label, :string, default: nil)
  attr(:role, :atom, default: nil)
  attr(:my_role, :atom, required: true)
  attr(:me?, :boolean, default: false)
  attr(:pending?, :boolean, default: false)
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
      <div class="flex items-center gap-x-3 sm:gap-x-5">
        <img
          :if={not @pending?}
          src={User.profile_img_url(@user)}
          class="size-8 shrink-0 rounded-full bg-gray-300"
        />
        <div
          :if={@pending?}
          class="size-8 shrink-0 flex items-center justify-center rounded-full bg-indigo-500"
        >
          <Heroicons.envelope class="size-4 text-white" />
        </div>
        <div class="flex flex-col min-w-0">
          <div class="flex items-center gap-x-1 text-sm font-medium">
            <span :if={@pending?} class="truncate">Pending invitation</span>
            <span :if={not @pending?} class="truncate">{@user.name}</span>
            <span
              :if={@label && @me?}
              class="shrink-0 dark:bg-indigo-600 dark:text-gray-200 bg-gray-150 text-gray-500 text-xs px-1 py-0.5 rounded-md"
            >
              {@label}
            </span>
            <.pill :if={@label && not @me?} color={:gray} class="shrink-0">{@label}</.pill>
          </div>
          <span class="text-gray-500 text-xs truncate">
            {@user.email}
          </span>
        </div>
        <div class="flex-1 shrink-0 flex items-center justify-end gap-x-2">
          <.role_switcher
            id={"role-dropdown-#{@user.email}"}
            user={@user}
            role={@role}
            my_role={@my_role}
            me?={@me?}
            disabled={@disabled}
          />

          <.delete_button
            id={"#{:erlang.phash2(@user.email)}-remove"}
            class="disabled:cursor-not-allowed"
            disabled={@disabled or @remove_disabled}
            aria-label="Remove member"
            phx-click="remove-member"
            phx-value-email={@user.email}
            phx-value-name={@user.name}
            data-confirm="Are you sure you want to remove this member from the team?"
          />
        </div>
      </div>
    </div>
    """
  end

  attr(:id, :string, required: true)
  attr(:user, User, required: true)
  attr(:role, :atom, required: true)
  attr(:my_role, :atom, required: true)
  attr(:me?, :boolean, default: false)
  attr(:disabled, :boolean, default: false)

  def role_switcher(assigns) do
    ~H"""
    <PrimaListbox.listbox id={@id} name={"#{@id}-value"} value={@role} disabled={@disabled}>
      <PrimaListbox.listbox_trigger
        id={"#{@id}-trigger"}
        aria-label="Role"
        disabled={@disabled}
        class="role !border-none !shadow-none !bg-transparent dark:!bg-transparent hover:!bg-gray-100 dark:hover:!bg-gray-700"
      >
        <PrimaListbox.listbox_value>
          {role_to_capitalized_string(@role)}
        </PrimaListbox.listbox_value>
        <Heroicons.chevron_down mini class="size-4 mt-0.5" />
      </PrimaListbox.listbox_trigger>

      <PrimaListbox.listbox_options id={"#{@id}-options"} class="max-w-60">
        <.role_item
          :for={{role, description} <- selectable_role_descriptions(@my_role)}
          user={@user}
          id={"option-#{:erlang.phash2(@user.email)}-#{role}"}
          phx-value-email={@user.email}
          phx-value-name={@user.name}
          role={role}
          disabled={@disabled or @role == role}
          dispatch_animation?={@role == :guest}
          data-confirm={if @me? and role in [:editor, :billing, :viewer], do: lower_role_warning()}
        >
          {description}
        </.role_item>
      </PrimaListbox.listbox_options>
    </PrimaListbox.listbox>
    """
  end

  attr(:id, :string, required: true)
  attr(:role, :atom, required: true)
  attr(:my_role, :atom, required: true)
  attr(:rest, :global)

  def role_select_input(assigns) do
    ~H"""
    <PrimaListbox.listbox id={@id} name={"#{@id}-value"} value={@role}>
      <PrimaListbox.listbox_trigger id={"#{@id}-trigger"} aria-label="Role" class="w-[100px]">
        <PrimaListbox.listbox_value>
          {role_to_capitalized_string(@role)}
        </PrimaListbox.listbox_value>
        <Heroicons.chevron_down mini class="size-4 mt-0.5" />
      </PrimaListbox.listbox_trigger>

      <PrimaListbox.listbox_options id={"#{@id}-options"} class="max-w-64">
        <PrimaListbox.listbox_option
          :for={{role, description} <- selectable_role_descriptions(@my_role)}
          id={"#{@id}-option-#{role}"}
          value={role}
          display={role_to_capitalized_string(role)}
          phx-value-role={role}
          {@rest}
        >
          <div>{role_to_capitalized_string(role)}</div>
          <PrimaListbox.option_description class="whitespace-nowrap">
            {description}
          </PrimaListbox.option_description>
        </PrimaListbox.listbox_option>
      </PrimaListbox.listbox_options>
    </PrimaListbox.listbox>
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
    <PrimaListbox.listbox_option
      id={@id}
      value={@role}
      display={role_to_capitalized_string(@role)}
      disabled={@disabled}
      phx-click={@click}
      phx-value-role={@role}
      {@rest}
    >
      <div class="flex items-center justify-between gap-x-2">
        <span>{role_to_capitalized_string(@role)}</span>
        <Heroicons.check
          mini
          class="size-4 text-indigo-600 dark:text-indigo-400 hidden group-data-selected:inline"
        />
      </div>
      <PrimaListbox.option_description disabled={@disabled}>
        {render_slot(@inner_block)}
      </PrimaListbox.option_description>
    </PrimaListbox.listbox_option>
    """
  end

  defp selectable_role_descriptions(my_role) do
    Enum.reject(@role_descriptions, fn {role, _description} ->
      role_change_disabled?(my_role, role)
    end)
  end

  defp role_change_disabled?(my_role, :owner), do: my_role != :owner
  defp role_change_disabled?(my_role, _role), do: my_role not in [:owner, :admin]

  defp lower_role_warning() do
    "You're about to lower your own role. Some team management features will no longer be accessible to you, and you'll need to ask a team owner to restore your access. Do you want to continue?"
  end
end
