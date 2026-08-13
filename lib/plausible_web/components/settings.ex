defmodule PlausibleWeb.Components.Settings do
  @moduledoc """
  Shared layout components for settings pages.
  """
  use Phoenix.Component, global_prefixes: ~w(x-)

  import PlausibleWeb.Components.Generic

  alias PlausibleWeb.Live.Components.Form

  def settings_tiles(assigns) do
    ~H"""
    <div class="text-gray-900 leading-5 dark:text-gray-100">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :docs, :string, default: nil
  slot :inner_block, required: true
  slot :title, required: true
  slot :subtitle, required: false
  attr :feature_mod, :atom, default: nil
  attr :feature_toggle?, :boolean, default: false
  attr :current_team, :any, default: nil
  attr :current_user, :any, default: nil
  attr :site, :any, default: nil
  attr :conn, :any, default: nil
  attr :show_content?, :boolean, default: true

  def tile(assigns) do
    ~H"""
    <div data-test-id="settings-tile" class="shadow-sm bg-white dark:bg-gray-900 rounded-md mb-6">
      <header class="relative py-4 px-6">
        <.title>
          {render_slot(@title)}

          <.docs_info :if={@docs} slug={@docs} class="absolute top-4 right-4 z-1" />
        </.title>
        <div :if={@subtitle != []} class="text-sm mt-px text-gray-500 dark:text-gray-400 leading-5">
          {render_slot(@subtitle)}
        </div>

        <.live_component
          :if={@feature_toggle?}
          module={PlausibleWeb.Components.Site.Feature.ToggleLive}
          id={"feature-toggle-#{@site.id}-#{@feature_mod}"}
          site={@site}
          feature_mod={@feature_mod}
          current_user={@current_user}
        />
      </header>
      <div class={["border-b dark:border-gray-700 mx-6", if(not @show_content?, do: "hidden")]}></div>
      <div class={["relative", if(not @show_content?, do: "hidden")]}>
        <%= if @feature_mod do %>
          <PlausibleWeb.Components.Billing.feature_gate
            locked?={@feature_mod.check_availability(@current_team) != :ok}
            current_user={@current_user}
            current_team={@current_team}
            site={@site}
          >
            <div class="p-4 sm:p-6">
              {render_slot(@inner_block)}
            </div>
          </PlausibleWeb.Components.Billing.feature_gate>
        <% else %>
          <div class="p-4 sm:p-6">
            {render_slot(@inner_block)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  slot :inner_block, required: true

  def settings_rows(assigns) do
    ~H"""
    <div class="flex flex-col gap-6">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:label, :string, default: nil)
  attr(:for, :string, default: nil)
  attr(:docs, :string, default: nil)
  attr(:tooltip, :string, default: nil)
  attr(:actions_class, :any, default: "gap-2.5")
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def settings_row(assigns) do
    ~H"""
    <div
      class="flex flex-col items-stretch gap-3 sm:flex-row sm:items-center sm:gap-4 text-sm"
      {@rest}
    >
      <.settings_label
        :if={@label}
        label={@label}
        for={@for}
        docs={@docs}
        tooltip={@tooltip}
      />
      <div class={["flex items-center sm:ml-auto", @actions_class]}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:docs, :string, default: nil)
  attr(:tooltip, :string, default: nil)
  attr(:expandable?, :boolean, default: false)
  slot(:inner_block, required: true)

  def settings_section(%{expandable?: true} = assigns) do
    ~H"""
    <section class="flex flex-col gap-6" x-data="{ open: false }">
      <button
        type="button"
        class="flex items-center justify-between gap-4"
        aria-expanded="false"
        x-bind:aria-expanded="open"
        x-on:click="open = !open"
      >
        <.settings_label label={@title} docs={@docs} tooltip={@tooltip} />
        <Heroicons.chevron_down
          mini
          class="size-4.5 text-gray-500 dark:text-gray-400 transition-transform"
          x-bind:class="open ? 'rotate-180' : ''"
        />
      </button>
      <div x-show="open" x-cloak class="flex flex-col gap-4">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  def settings_section(assigns) do
    ~H"""
    <section class="flex flex-col gap-6">
      <.settings_label label={@title} docs={@docs} tooltip={@tooltip} />
      <div class="flex flex-col gap-4">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  attr(:label, :string, required: true)
  attr(:for, :string, default: nil)
  attr(:docs, :string, default: nil)
  attr(:tooltip, :string, default: nil)

  def settings_label(assigns) do
    ~H"""
    <div class="flex items-center gap-1.5">
      <Form.label :if={@for} for={@for}>{@label}</Form.label>
      <span :if={!@for} class="text-sm font-medium dark:text-gray-100">{@label}</span>
      <.docs_info :if={@docs} slug={@docs} />
      <.tooltip :if={@tooltip} centered?={true}>
        <:tooltip_content>{@tooltip}</:tooltip_content>
        <Heroicons.information_circle class="size-4.5 text-gray-400 dark:text-gray-500" />
      </.tooltip>
    </div>
    """
  end

  def settings_divider(assigns) do
    ~H"""
    <hr class="border-gray-200 dark:border-gray-700" />
    """
  end
end
