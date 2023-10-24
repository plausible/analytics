defmodule PlausibleWeb.Live.Sites do
  @moduledoc """
  LiveView for sites index.
  """

  use Phoenix.LiveView
  use Phoenix.HTML

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Sites

  def mount(params, %{"current_user_id" => user_id}, socket) do
    socket =
      socket
      |> assign_new(:user, fn -> Repo.get!(Auth.User, user_id) end)
      |> assign_new(:sites, fn %{user: user} -> Sites.list(user, params) end)
      |> assign_new(:visitors, fn %{sites: sites} ->
        Plausible.Stats.Clickhouse.last_24h_visitors(sites.entries)
      end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container pt-6">
      <div class="mt-6 pb-5 border-b border-gray-200 dark:border-gray-500 flex items-center justify-between">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 dark:text-gray-100 sm:text-3xl sm:leading-9 sm:truncate flex-shrink-0">
          My Sites
        </h2>
        <a href="/sites/new" class="button my-2 sm:my-0 w-auto">+ Add Website</a>
      </div>

      <ul class="my-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <%= if Enum.empty?(@sites.entries) do %>
          <p class="dark:text-gray-100">You don't have any sites yet</p>
        <% end %>

        <%= for site <- @sites.entries do %>
          <div class="relative">
            <%= link(to: "/" <> URI.encode_www_form(site.domain)) do %>
              <li class="col-span-1 bg-white dark:bg-gray-800 rounded-lg shadow p-4 group-hover:shadow-lg cursor-pointer">
                <div class="w-full flex items-center justify-between space-x-4">
                  <.favicon domain={site.domain} />
                  <div class="flex-1 -mt-px w-full">
                    <h3
                      class="text-gray-900 font-medium text-lg truncate dark:text-gray-100"
                      style="width: calc(100% - 4rem)"
                    >
                      <%= site.domain %>
                    </h3>
                  </div>
                </div>
                <div class="pl-8 mt-2 flex items-center justify-between">
                  <span class="text-gray-600 dark:text-gray-400 text-sm truncate">
                    <span class="text-gray-800 dark:text-gray-200">
                      <b>
                        <%= PlausibleWeb.StatsView.large_number_format(
                          Map.get(@visitors, site.domain, 0)
                        ) %>
                      </b>
                      visitor<%= if Map.get(@visitors, site.domain, 0) != 1 do %>
                        s
                      <% end %>
                      in last 24h
                    </span>
                  </span>
                </div>
              </li>
            <% end %>
            <%= if List.first(site.memberships).role != :viewer do %>
              <%= link(to: "/" <> URI.encode_www_form(site.domain) <> "/settings", class: "absolute top-0 right-0 p-4 mt-1") do %>
                <svg
                  class="w-5 h-5 text-gray-600 dark:text-gray-400 transition hover:text-gray-900 dark:hover:text-gray-100"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <path
                    fill-rule="evenodd"
                    d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z"
                    clip-rule="evenodd"
                  >
                  </path>
                </svg>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </ul>
    </div>
    """
  end

  def favicon(assigns) do
    src = "/favicon/sources/#{assigns.domain}"
    assigns = assign(assigns, :src, src)

    ~H"""
    <img src={@src} class="w-4 h-4 flex-shrink-0 mt-px" />
    """
  end
end
