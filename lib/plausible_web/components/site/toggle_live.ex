defmodule PlausibleWeb.Components.Site.Feature.ToggleLive do
  @moduledoc """
  LiveComponent for rendering a user-facing feature toggle in LiveView contexts.
  Instead of using form submission, this component messages itself to handle toggles.
  """
  use PlausibleWeb, :live_component

  def update(assigns, socket) do
    site = Plausible.Repo.preload(assigns.site, :team)
    team = Plausible.Teams.with_subscription(site.team)
    site = %{site | team: team}
    current_setting = assigns.feature_mod.enabled?(site)
    disabled? = assigns.feature_mod.check_availability(team) !== :ok

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:site, site)
     |> assign(:current_setting, current_setting)
     |> assign(:disabled?, disabled?)}
  end

  attr :site, Plausible.Site, required: true
  attr :feature_mod, :atom, required: true
  attr :current_user, Plausible.Auth.User, required: true

  def render(assigns) do
    ~H"""
    <div class="mt-4" id={"feature-#{@feature_mod.name()}-toggle"}>
      <div class="my-2 flex items-center">
        <button
          type="button"
          phx-click="toggle"
          phx-target={@myself}
          class={[
            "relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full transition-colors ease-in-out duration-200",
            if(@current_setting, do: "bg-indigo-600", else: "bg-gray-200 dark:bg-gray-600"),
            if(@disabled?, do: "cursor-not-allowed")
          ]}
          disabled={@disabled?}
        >
          <span
            aria-hidden="true"
            class={[
              "inline-block size-5 rounded-full bg-white shadow transform transition ease-in-out duration-200",
              if(@current_setting, do: "translate-x-5", else: "translate-x-0")
            ]}
          />
        </button>

        <span class={[
          "ml-2 font-medium leading-5 text-sm",
          if(@disabled?,
            do: "text-gray-500 dark:text-gray-400",
            else: "text-gray-900 dark:text-gray-100"
          )
        ]}>
          Show in dashboard
        </span>
      </div>
    </div>
    """
  end

  def handle_event("toggle", _params, socket) do
    site = socket.assigns.site
    feature_mod = socket.assigns.feature_mod
    current_user = socket.assigns.current_user

    case feature_mod.toggle(site, current_user) do
      {:ok, updated_site} ->
        new_setting = Map.fetch!(updated_site, feature_mod.toggle_field())

        message =
          if new_setting do
            "#{feature_mod.display_name()} are now visible again on your dashboard"
          else
            "#{feature_mod.display_name()} are now hidden from your dashboard"
          end

        send(self(), {:feature_toggled, message, updated_site})

        socket =
          assign(socket, site: updated_site, current_setting: feature_mod.enabled?(updated_site))

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end
end
