defmodule PlausibleWeb.Live.CustomerSupport.User do
  @moduledoc """
  User coordinator LiveView for Customer Support interface.

  Manages tab-based navigation and delegates rendering to specialized 
  components: Overview and API Keys.
  """
  use PlausibleWeb.CustomerSupport.Live

  import Ecto.Query
  alias Plausible.Repo

  alias PlausibleWeb.CustomerSupport.User.Components.{
    Overview,
    Keys
  }

  def handle_params(%{"id" => user_id} = params, _uri, socket) do
    tab = params["tab"] || "overview"
    user = Resource.User.get(user_id)

    if user do
      keys_count = count_keys(user)

      socket =
        socket
        |> assign(:user, user)
        |> assign(:tab, tab)
        |> assign(:keys_count, keys_count)

      {:noreply, go_to_tab(socket, tab, params, :user, tab_component(tab))}
    else
      {:noreply, redirect(socket, to: Routes.customer_support_path(socket, :index))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layout.layout show_search={false} flash={@flash}>
      <div class="overflow-hidden rounded-lg">
        <.user_header user={@user} />
        <.user_tab_navigation user={@user} tab={@tab} keys_count={@keys_count} />

        <.live_component
          module={tab_component(@tab)}
          user={@user}
          tab={@tab}
          id={"user-#{@user.id}-#{@tab}"}
        />
      </div>
    </Layout.layout>
    """
  end

  defp user_header(assigns) do
    ~H"""
    <div class="sm:flex sm:items-center sm:justify-between">
      <div class="sm:flex sm:space-x-5">
        <div class="shrink-0">
          <div class="rounded-full p-1 flex items-center justify-center">
            <img
              src={Plausible.Auth.User.profile_img_url(@user)}
              class="w-14 rounded-full bg-gray-300"
            />
          </div>
        </div>
        <div class="mt-4 text-center sm:mt-0 sm:pt-1 sm:text-left">
          <p class="text-xl font-bold sm:text-2xl">
            <div class="flex items-center gap-x-2">
              {@user.name}
              <span :if={@user.type == :sso} class="bg-green-700 text-gray-100 text-xs p-1 rounded">
                SSO
              </span>
            </div>
          </p>
          <p class="text-sm font-medium">{@user.email}</p>
        </div>
      </div>

      <div class="mt-5 flex justify-center sm:mt-0">
        <.input_with_clipboard
          id="user-identifier"
          name="user-identifier"
          label="User Identifier"
          value={@user.id}
        />
      </div>
    </div>
    """
  end

  defp user_tab_navigation(assigns) do
    ~H"""
    <.tab_navigation tab={@tab}>
      <:tabs>
        <.tab to="overview" tab={@tab}>Overview</.tab>
        <.tab to="keys" tab={@tab}>
          API Keys ({@keys_count})
        </.tab>
      </:tabs>
    </.tab_navigation>
    """
  end

  defp tab_component("overview"), do: Overview
  defp tab_component("keys"), do: Keys
  defp tab_component(_), do: Overview

  defp count_keys(user) do
    from(api_key in Plausible.Auth.ApiKey,
      where: api_key.user_id == ^user.id
    )
    |> Repo.aggregate(:count)
  end
end
