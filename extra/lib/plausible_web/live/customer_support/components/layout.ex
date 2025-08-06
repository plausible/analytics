defmodule PlausibleWeb.CustomerSupport.Components.Layout do
  @moduledoc """
  Base layout component for Customer Support UI
  Provides common header, filter bar, and content area structure
  """
  use PlausibleWeb, :component
  import PlausibleWeb.Live.Flash

  attr :filter_text, :string, default: ""
  attr :show_search, :boolean, default: true
  attr :flash, :map, default: %{}
  slot :inner_block, required: true
  slot :filter_actions, required: false

  def layout(assigns) do
    ~H"""
    <div x-data="{ openHelp: false }" class="dark:text-gray-400">
      <.help_overlay />

      <div class="container pt-6">
        <.header filter_text={@filter_text} />

        <div class="py-4">
          <.styled_link class="text-sm" onclick="window.history.go(-1); return false;">
            &larr; Go back
          </.styled_link>
        </div>

        <.search_bar :if={@show_search} filter_text={@filter_text}>
          {render_slot(@filter_actions)}
        </.search_bar>

        <.flash_messages flash={@flash} />

        <div class="mt-4">
          {render_slot(@inner_block)}
        </div>

        <div class="py-4">
          <.styled_link class="text-sm" onclick="window.history.go(-1); return false;">
            &larr; Go back
          </.styled_link>
        </div>
      </div>
    </div>
    """
  end

  defp help_overlay(assigns) do
    ~H"""
    <div
      id="help"
      x-show="openHelp"
      x-cloak
      class="p-16 fixed top-0 left-0 w-full h-full bg-gray-800 text-gray-300 bg-opacity-95 z-50 flex items-center justify-center"
    >
      <div @click.away="openHelp = false" @click="openHelp = false">
        Prefix your searches with: <br /><br />
        <div class="font-mono">
          <strong>site:</strong>input<br />
          <p class="font-sans pl-2 mb-1">
            Search for sites exclusively. Input will be checked against site's domain, team's name, owners' names and e-mails.
          </p>
          <strong>user:</strong>input<br />
          <p class="font-sans pl-2 mb-1">
            Search for users exclusively. Input will be checked against user's name and e-mail.
          </p>
          <strong>team:</strong>input<br />
          <p class="font-sans pl-2 mb-1">
            Search for teams exclusively. Input will be checked against user's name and e-mail.
          </p>

          <strong>team:</strong>input <strong>+sub</strong>
          <br />
          <p class="font-sans pl-2 mb-1">
            Like above, but only finds team(s) with subscription (in any status).
          </p>

          <strong>team:</strong>input <strong>+sso</strong>
          <br />
          <p class="font-sans pl-2 mb-1">
            Like above, but only finds team(s) with SSO integrations (in any status).
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :filter_text, :string, required: true

  defp header(assigns) do
    ~H"""
    <div class="group mt-6 pb-5 border-b border-gray-200 dark:border-gray-500 flex items-center justify-between">
      <h2 class="text-2xl font-bold leading-7 text-gray-900 dark:text-gray-100 sm:text-3xl sm:leading-9 sm:truncate flex-shrink-0">
        <.link
          replace
          patch={
            Routes.customer_support_path(PlausibleWeb.Endpoint, :index, %{filter_text: @filter_text})
          }
        >
          💬 Customer Support
        </.link>
      </h2>
    </div>
    """
  end

  attr :filter_text, :string, required: true
  slot :inner_block, required: false

  defp search_bar(assigns) do
    ~H"""
    <div class="mb-4 mt-4">
      <.filter_bar filter_text={@filter_text} placeholder="Search everything">
        <a class="cursor-pointer" @click="openHelp = !openHelp">
          <Heroicons.question_mark_circle class="text-indigo-700 dark:text-gray-500 w-5 h-5 hover:stroke-2" />
        </a>
        {render_slot(@inner_block)}
      </.filter_bar>
    </div>
    """
  end
end
