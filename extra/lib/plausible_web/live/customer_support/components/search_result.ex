defmodule PlausibleWeb.CustomerSupport.Components.SearchResult do
  @moduledoc """
  Component responsible for rendering search result cards for customer support resources
  """
  use PlausibleWeb, :live_component

  def favicon(assigns) do
    ~H"""
    <img src={"/favicon/sources/#{@domain}"} class={@class} />
    """
  end

  def render_result(%{resource: %{type: "team"}} = assigns) do
    ~H"""
    <div class="flex-1 -mt-px w-full">
      <div class="w-full flex items-center justify-between space-x-4">
        <div class="w-5 h-5 rounded-full bg-blue-500 flex items-center justify-center">
          <span class="text-white text-xs font-bold">T</span>
        </div>
        <h3
          class="text-gray-900 font-medium text-lg truncate dark:text-gray-100"
          style="width: calc(100% - 4rem)"
        >
          {@resource.object.name}
        </h3>

        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
          Team
        </span>
        <span
          :if={@resource.object.subscription}
          class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800"
          >
          $
        </span>
      </div>

      <hr class="mt-4 mb-4 flex-grow border-t border-gray-200 dark:border-gray-600" />
    <div class="text-sm truncate">
        Team identifier:
        <code class="font-mono">{@resource.object.identifier |> String.slice(0, 8)}</code>
        <br />
        Owned by: {@resource.object.owners
        |> Enum.map(& &1.name)
        |> Enum.join(", ")}
      </div>
    </div>
    """
  end

  def render_result(%{resource: %{type: "user"}} = assigns) do
    ~H"""
    <div class="flex-1 -mt-px w-full">
      <div class="w-full flex items-center justify-between space-x-4">
        <img src={Plausible.Auth.User.profile_img_url(@resource.object)} class="h-5 w-5 rounded-full" />
        <h3
          class="text-gray-900 font-medium text-lg truncate dark:text-gray-100"
          style="width: calc(100% - 4rem)"
        >
          {@resource.object.name}
        </h3>

        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800">
          User
        </span>
      </div>

      <hr class="mt-4 mb-4 flex-grow border-t border-gray-200 dark:border-gray-600" />
      <div class="text-sm truncate">
        {@resource.object.name} &lt;{@resource.object.email}&gt; <br />
        Owns {length(@resource.object.owned_teams)} team(s)
      </div>
    </div>
    """
  end

  def render_result(%{resource: %{type: "site"}} = assigns) do
    ~H"""
    <div class="flex-1 -mt-px w-full">
      <div class="w-full flex items-center justify-between space-x-4">
        <.favicon class="w-5" domain={@resource.object.domain} />
        <h3
          class="text-gray-900 font-medium text-lg truncate dark:text-gray-100"
          style="width: calc(100% - 4rem)"
        >
          {@resource.object.domain}
        </h3>

        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
          Site
        </span>
      </div>

      <hr class="mt-4 mb-4 flex-grow border-t border-gray-200 dark:border-gray-600" />
      <div class="text-sm truncate">
        Part of <strong>{@resource.object.team.name}</strong>
        <br />
        owned by {@resource.object.team.owners
        |> Enum.map(& &1.name)
        |> Enum.join(", ")}
      </div>
    </div>
    """
  end
end
