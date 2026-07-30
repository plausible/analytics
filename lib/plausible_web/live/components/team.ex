defmodule PlausibleWeb.Live.Components.Team do
  @moduledoc """
  Shared component base for listing team members/invitations
  alongside with the role dropdown.
  """
  use PlausibleWeb, :component
  import PlausibleWeb.Components.Generic

  alias Plausible.Auth.User
  alias Plausible.Billing.Quota
  alias Plausible.Teams.Management.Layout

  attr(:layout, :map, required: true)
  attr(:my_role, :atom, required: true)
  attr(:current_user, User, required: true)

  def member_list(assigns) do
    ~H"""
    <div id="member-list">
      <.member
        :for={{email, entry} <- Layout.sorted_for_display(@layout)}
        :if={entry.role != :guest}
        user={%User{email: entry.email, name: entry.name}}
        role={entry.role}
        label={entry_label(entry, @current_user)}
        me?={entry.id == @current_user.id}
        my_role={@my_role}
        remove_disabled={not Layout.removable?(@layout, email)}
        disabled={
          (entry.role == :owner && Layout.owners_count(@layout) == 1) or
            @my_role not in [:owner, :admin]
        }
      />
    </div>

    <div :if={Layout.has_guests?(@layout)} class="flex items-center mt-4 mb-4" id="guests-hr">
      <hr class="grow border-t border-gray-200 dark:border-gray-700" />
      <span class="mx-4 text-gray-500 text-sm">
        Guests
      </span>
      <hr class="grow border-t border-gray-200 dark:border-gray-700" />
    </div>

    <div :if={Layout.has_guests?(@layout)} id="guest-list">
      <.member
        :for={{email, entry} <- Layout.sorted_for_display(@layout)}
        :if={entry.role == :guest}
        user={%User{email: entry.email, name: entry.name}}
        role={entry.role}
        label={entry_label(entry, @current_user)}
        my_role={@my_role}
        remove_disabled={not Layout.removable?(@layout, email)}
        disabled={@my_role not in [:owner, :admin]}
      />
    </div>
    """
  end

  def entry_label(%Layout.Entry{role: :guest, type: :membership}, _), do: nil
  def entry_label(%Layout.Entry{type: :invitation_pending}, _), do: "Invitation pending"
  def entry_label(%Layout.Entry{type: :invitation_sent}, _), do: "Invitation sent"

  def entry_label(%Layout.Entry{meta: %{user: %{id: id, type: :sso}}}, %{id: id}),
    do: "You (SSO)"

  def entry_label(%Layout.Entry{meta: %{user: %{id: id}}}, %{id: id}), do: "You"
  def entry_label(%Layout.Entry{meta: %{user: %{type: :sso}}}, _), do: "SSO"
  def entry_label(_, _), do: nil

  def persist_error_message(:permission_denied), do: "Permission denied"
  def persist_error_message(:only_one_owner), do: "The team has to have at least one owner"

  def persist_error_message(:disabled_2fa),
    do: "User must have 2FA enabled to become an owner"

  def persist_error_message({:over_limit, limit}) do
    "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit"
  end

  @doc """
  Whether the team is at its member limit, counting any members pending
  addition on top of the ones already in the layout. The team owner does not
  count towards the limit.
  """
  def at_limit?(layout, limit, pending_count \\ 0) do
    not Quota.below_limit?(Layout.active_count(layout) - 1 + pending_count, limit)
  end

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
                data-confirm={if @me?, do: lower_role_warning()}
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
                data-confirm={if @me?, do: lower_role_warning()}
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
                data-confirm={if @me?, do: lower_role_warning()}
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

  defp lower_role_warning() do
    "You're about to lower your own role. Some team management features will no longer be accessible to you, and you'll need to ask a team owner to restore your access. Do you want to continue?"
  end
end
