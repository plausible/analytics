defmodule PlausibleWeb.Live.Components.Verification do
  @moduledoc """
  This component is responsible for rendering the verification progress
  and diagnostics.
  """
  use Phoenix.LiveComponent
  use Plausible

  import PlausibleWeb.Components.Generic

  attr :domain, :string, required: true
  attr :modal?, :boolean, default: false

  attr :message, :string, default: "We're visiting your site to ensure that everything is working"

  attr :finished?, :boolean, default: false
  attr :success?, :boolean, default: false
  attr :interpretation, Plausible.Verification.Diagnostics.Result, default: nil
  attr :attempts, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div
      class={[
        "dark:text-gray-100 text-center bg-white dark:bg-gray-800 flex flex-col",
        if(not @modal?, do: "shadow-md rounded px-8 pt-6 pb-4 mb-4 mt-16 h-96", else: "h-72")
      ]}
      id="progress-indicator"
    >
      <div
        :if={not @finished? or (not @modal? and @success?)}
        class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-green-100 dark:bg-gray-700"
      >
        <div class="block pulsating-circle" }></div>
      </div>

      <div
        :if={@finished? and @success? and @modal?}
        class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-green-100 dark:bg-green-500"
        id="check-circle"
      >
        <Heroicons.check_badge class="h-6 w-6 text-green-600 bg-green-100 dark:bg-green-500 dark:text-green-200" />
      </div>

      <div
        :if={@finished? and not @success?}
        class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-red-100 dark:bg-red-200"
        id="error-circle"
      >
        <Heroicons.exclamation_triangle class="h-6 w-6 text-red-600 bg-red-100 dark:bg-red-200 dark:text-red-800" />
      </div>

      <div class="mt-6">
        <h3 class="font-semibold leading-6 text-xl">
          <span :if={@finished? and @success?}>Success!</span>
          <span :if={not @finished?}>Verifying your integration</span>

          <span :if={@finished? and not @success? and @interpretation}>
            <%= List.first(@interpretation.errors) %>
          </span>
        </h3>
        <p :if={@finished? and @success? and @modal?} id="progress" class="mt-2">
          Your integration is working and visitors are being counted accurately
        </p>
        <p :if={@finished? and @success? and not @modal?} id="progress" class="mt-2 animate-pulse">
          Your integration is working. Awaiting your first pageview.
        </p>
        <p :if={not @finished?} class="mt-2 animate-pulse" id="progress"><%= @message %></p>

        <.recommendations
          :if={@finished? and not @success? and @interpretation}
          interpretation={@interpretation}
        />
      </div>

      <div :if={@finished?} class="mt-auto">
        <.button_link :if={not @success?} href="#" phx-click="retry" class="font-bold w-full">
          Verify integration again
        </.button_link>
        <.button_link
          :if={@success?}
          href={"/#{URI.encode_www_form(@domain)}?skip_to_dashboard=true"}
          class="w-full font-bold mb-4"
        >
          Go to the dashboard
        </.button_link>
      </div>

      <div
        :if={
          (not @modal? and not @success?) or
            (@finished? and not @success?)
        }
        class="mt-auto text-sm"
      >
        <%= if ee?() and @finished? and not @success? and @attempts >= 3 do %>
          Need further help with your integration? Do
          <.styled_link href="https://plausible.io/contact">
            contact us
          </.styled_link>
          <br />
        <% end %>
        <%= if not @success? and not @modal? do %>
          Need to see the snippet again?
          <.styled_link href={"/#{URI.encode_www_form(@domain)}/snippet"}>
            Click here
          </.styled_link>
          <br /> Run verification later and go to Site Settings?
          <.styled_link href={"/#{URI.encode_www_form(@domain)}/settings/general"}>
            Click here
          </.styled_link>
          <br />
        <% end %>
      </div>
    </div>
    """
  end

  def recommendations(assigns) do
    ~H"""
    <p class="mt-2" id="recommendations">
      <span :for={recommendation <- @interpretation.recommendations} class="recommendation">
        <span :if={is_binary(recommendation)}><%= recommendation %></span>
        <span :if={is_tuple(recommendation)}><%= elem(recommendation, 0) %>.&nbsp;</span>
        <.styled_link :if={is_tuple(recommendation)} href={elem(recommendation, 1)} new_tab={true}>
          Learn more
        </.styled_link>
        <br />
      </span>
    </p>
    """
  end
end
