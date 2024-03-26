defmodule PlausibleWeb.Components.FirstDashboardLaunchBanner do
  @moduledoc """
  A banner that appears on the first dashboard launch
  """
  use Phoenix.Component
  use Phoenix.HTML

  attr(:site, Plausible.Site, required: true)

  def set(assigns) do
    ~H"""
    <script>
      sessionStorage.setItem('<%= storage_key(@site) %>', false);
    </script>
    """
  end

  attr(:site, Plausible.Site, required: true)

  def render(assigns) do
    ~H"""
    <div
      x-cloak
      x-data={x_data(@site)}
      class="w-full px-4 text-sm font-bold text-center text-blue-900 bg-blue-200 rounded transition"
      style="top: 91px"
      role="alert"
      x-bind:class="! show ? 'hidden' : ''"
      x-init={x_init(@site)}
    >
      <%= link("Team members, email reports and GA import. Explore more →",
        to: "/#{URI.encode_www_form(@site.domain)}/settings/email-reports",
        class: "py-2 block"
      ) %>
    </div>
    """
  end

  defp x_data(site) do
    "{show: !!sessionStorage.getItem('#{storage_key(site)}')}"
  end

  defp x_init(site) do
    "setTimeout(() => sessionStorage.removeItem('#{storage_key(site)}'), 3000)"
  end

  defp storage_key(site) do
    "dashboard_seen_#{site.domain}"
  end
end
