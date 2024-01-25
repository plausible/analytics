defmodule PlausibleWeb.Live.Shields do
  @moduledoc """
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias PlausibleWeb.Live.Components.Modal
  import PlausibleWeb.Live.Components.Form
  import PlausibleWeb.Components.Generic

  def mount(
        _params,
        %{
          "remote_ip" => remote_ip,
          "site_id" => site_id,
          "domain" => domain,
          "current_user_id" => user_id
        },
        socket
      ) do
    {:ok,
     assign(socket, remote_ip: remote_ip, site_id: site_id, domain: domain, user_id: user_id)}
  end

  def render(assigns) do
    ~H"""
    <div class="border-t border-gray-200 pt-4 grid">
      <div class="mt-4 sm:ml-4 sm:mt-0 justify-self-end">
        <PlausibleWeb.Components.Generic.button
          id=""
          x-data
          x-on:click={Modal.JS.open("ip-form-modal")}
        >
          + Add IP Address
        </PlausibleWeb.Components.Generic.button>
      </div>
    </div>

    <.live_component module={Modal} id="ip-form-modal">
      <.form class="max-w-md w-full mx-auto bg-white dark:bg-gray-800" phx-submit="save-ip">
        <h2 class="text-xl font-black dark:text-gray-100 mb-8">Add IP to Block List</h2>

        <.input
          name={}
          value={}
          autofocus
          label="IP Address"
          class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-7/12 rounded-md sm:text-sm border-gray-300 dark:border-gray-500 w-full p-2 mt-2"
          autocomplete="off"
        />

        <p class="text-sm mt-2 text-gray-500 dark:text-gray-200 mb-4">
          Your current IP address is: <span class="font-mono"><%= @remote_ip %></span>
          <br />
          <.styled_link href={}>Click here</.styled_link>
          to block your own traffic, or enter a custom address.
        </p>

        <.input
          name={}
          value={}
          autofocus
          label="Description"
          class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-7/12 rounded-md sm:text-sm border-gray-300 dark:border-gray-500 w-full p-2 mt-2"
          value="Added by user@plausible.io"
          autocomplete="off"
        />

        <p class="text-sm mt-2 text-gray-500 dark:text-gray-200">
          Once added, we will start rejecting traffic from this IP within a few minutes.
        </p>
        <div class="py-4 mt-8">
          <PlausibleWeb.Components.Generic.button type="submit" class="w-full">
            Add IP Address →
          </PlausibleWeb.Components.Generic.button>
        </div>
      </.form>
    </.live_component>

    <div class="mt-8 overflow-hidden border-b border-gray-200 shadow dark:border-gray-900 sm:rounded-lg">
      <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-900">
        <thead class="bg-gray-50 dark:bg-gray-900">
          <tr>
            <th
              scope="col"
              class="px-6 py-3 text-xs font-medium text-left text-gray-500 uppercase dark:text-gray-100"
            >
              IP Address
            </th>
            <th
              scope="col"
              class="px-6 py-3 text-xs font-medium text-left text-gray-500 uppercase dark:text-gray-100"
            >
              Status
            </th>
            <th
              scope="col"
              class="px-6 py-3 text-xs font-medium text-left text-gray-500 uppercase dark:text-gray-100"
            >
              Description
            </th>
            <th scope="col" class="px-6 py-3">
              <span class="sr-only">Revoke</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <%= for {ip, name} <- [
          {"10.20.30.40", "john@example.com"},
          {"20.30.30.40", "clara@example.com"},
            {"84.10.115.148", "user@plausible.io"},
          {"80.30.30.40", "madelin@example.com"},
          {"90.30.30.40", "jane@example.com"},
        ] do %>
            <tr class="text-gray-500 dark:text-gray-100">
              <td class="px-6 py-4 text-xs font-medium">
                <div class="flex items-center">
                  <span class="font-mono mr-4">
                    <%= ip %>
                  </span>

                  <span
                    :if={ip == "84.10.115.148"}
                    class="inline-flex items-center gap-x-1.5 rounded-md px-2 py-1 text-xs font-medium text-white ring-1 ring-inset ring-gray-700"
                  >
                    <svg class="h-1.5 w-1.5 fill-green-400" viewBox="0 0 6 6" aria-hidden="true">
                      <circle cx="3" cy="3" r="3" />
                    </svg>
                    YOU
                  </span>
                </div>
              </td>
              <td class="px-6 py-4 text-sm">
                <span>
                  Blocked
                </span>
              </td>
              <td class="px-6 py-4 text-sm font-normal whitespace-nowrap">
                <span>
                  <%= name %>
                </span>
              </td>
              <td class="px-6 py-4 text-sm font-medium text-right">
                <span class="text-red-600">
                  Remove
                </span>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
