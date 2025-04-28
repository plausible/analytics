defmodule PlausibleWeb.CustomerSupport.Live.Site do
  use Plausible.CustomerSupport.Resource, :component

  def update(assigns, socket) do
    site = Resource.Site.get(assigns.resource_id)
    {:ok, assign(socket, site: site)}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-white p-6">
      <div class="sm:flex sm:items-center sm:justify-between">
        <div class="sm:flex sm:space-x-5">
          <div class="shrink-0">
            <div class="rounded-full p-1 flex items-center justify-center">
              <.favicon domain={@site.domain} />
            </div>
          </div>
          <div class="mt-4 text-center sm:mt-0 sm:pt-1 sm:text-left">
            <p class="text-xl font-bold text-gray-900 sm:text-2xl">
              {@site.domain}
            </p>
            <p class="text-sm font-medium text-gray-900">
              Timezone: {@site.timezone}
            </p>
            <p class="text-sm font-medium text-gray-600">
              <span :if={@site.domain_changed_from}>(previously: {@site.domain_changed_from})</span>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render_result(assigns) do
    ~H"""
    <div class="flex-1 -mt-px w-full">
      <div class="w-full flex items-center justify-between space-x-4">
        <.favicon domain={@resource.object.domain} />
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
      <div class="text-sm">
        Part of <strong>{@resource.object.team.name}</strong>
        owned by {@resource.object.team.owners
        |> Enum.map(& &1.name)
        |> Enum.join(", ")}
      </div>
    </div>
    """
  end

  def favicon(assigns) do
    src = "/favicon/sources/#{assigns.domain}"
    assigns = assign(assigns, :src, src)

    ~H"""
    <img src={@src} class="w-8" />
    """
  end
end
