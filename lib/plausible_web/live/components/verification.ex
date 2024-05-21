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

  attr :message, :string,
    default: "We're visiting your site to ensure that everything is working correctly"

  attr :finished?, :boolean, default: false
  attr :success?, :boolean, default: false
  attr :rating, Plausible.Verification.Diagnostics.Rating, default: nil
  attr :attempts, :integer, default: 0

  def render(assigns) do
    ~H"""
    <div class={[
      "bg-white dark:bg-gray-800 text-center h-96 flex flex-col",
      if(!@modal?, do: "shadow-md rounded px-8 pt-6 pb-4 mb-4 mt-16")
    ]}>
      <h2 class="text-xl font-bold dark:text-gray-100">
        <%= if @success? && @finished? do %>
          Success!
        <% else %>
          Verifying your integration
        <% end %>
      </h2>
      <h2 class="text-xl dark:text-gray-100 text-xs">
        <%= if @finished? && @success? do %>
          Your integration is working and visitors are being counted accurately
        <% else %>
          on <%= @domain %>
        <% end %>
      </h2>
      <div
        :if={!@finished? || @success?}
        class="flex justify-center w-full my-auto"
        id="progress-indicator"
      >
        <div class={["block pulsating-circle", if(@modal? && @finished?, do: "hidden")]}></div>
        <Heroicons.check_circle
          :if={@modal? && @finished? && @success?}
          id="check-circle"
          solid
          class="w-24 h-24 text-green-500 pt-8"
        />
      </div>

      <div
        :if={@finished? && !@success?}
        class="flex justify-center pt-3 h-14 mb-4 dark:text-gray-400 "
        id="progress-indicator"
      >
        <.shuttle width={50} height={50} />
      </div>
      <div
        id="progress"
        class={[
          "mt-2 dark:text-gray-400",
          if(!@finished?, do: "animate-pulse text-xs", else: "font-bold text-sm"),
          if(@finished? && !@success?, do: "text-red-500 dark:text-red-600")
        ]}
      >
        <p id="progress-message" class="leading-normal">
          <span :if={!@finished?}><%= @message %></span>
          <span :if={@finished? && !@success? && @rating && @rating.errors}>
            <%= List.first(@rating.errors) %>
            <div class="text-xs dark:text-gray-400 font-normal mt-1" id="recommendations">
              <.recommendations rating={@rating} />
            </div>
          </span>
          <p
            :if={@finished? && @success? && !@modal?}
            class="leading-normal animate-pulse text-xs font-normal"
          >
            Awaiting your first pageview.
          </p>
        </p>
      </div>

      <div class="mt-auto pb-2 text-gray-600 dark:text-gray-400 text-xs w-full text-center leading-normal">
        <div :if={@finished?} class="mb-4">
          <div class="flex justify-center gap-x-4 mt-4">
            <.button_link :if={!@success?} href="#" phx-click="retry" class="text-xs font-bold">
              Verify integration again
            </.button_link>
            <.button_link
              :if={@success?}
              href={"/#{URI.encode_www_form(@domain)}?skip_to_dashboard=true"}
              class="text-xs font-bold"
            >
              Go to the dashboard
            </.button_link>
          </div>
        </div>
        <%= if ee?() && @finished? && !@success? && @attempts >= 3 do %>
          Need further help with your integration? Do
          <.styled_link href="https://plausible.io/contact">
            contact us
          </.styled_link>
          <br />
        <% end %>
        <%= if !@modal? && !@success? do %>
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
    <p class="leading-normal">
      <span :for={recommendation <- @rating.recommendations} class="recommendation">
        <span :if={is_binary(recommendation)}><%= recommendation %></span>
        <span :if={is_tuple(recommendation)}><%= elem(recommendation, 0) %> -</span>
        <.styled_link
          :if={is_tuple(recommendation)}
          href={elem(recommendation, 1)}
          new_tab={true}
          class="text-xs"
        >
          Learn more
        </.styled_link>
        <br />
      </span>
    </p>
    """
  end
end
