defmodule PlausibleWeb.Components.Site.NewSiteForm do
  @moduledoc false

  use PlausibleWeb, :component

  attr :changeset, Ecto.Changeset, required: true
  attr :form_submit_url, :string, required: true
  attr :site_limit_exceeded?, :boolean, required: true
  attr :site_limit, :integer, required: true
  attr :current_user, :any, required: true
  attr :current_team, :any, required: true
  attr :back_button_text, :string, required: true
  attr :back_button_href, :string, required: true

  def new_site_form(assigns) do
    ~H"""
    <.heading_and_subtitle heading="Add a website" subtitle="Start measuring traffic on a new site." />
    <div class="w-full max-w-md mx-auto mt-10 pb-16 px-4 dark:text-gray-300">
      <.form :let={f} class="flex flex-col gap-y-8" for={@changeset} action={@form_submit_url}>
        <PlausibleWeb.Components.Billing.Notice.limit_exceeded
          :if={@site_limit_exceeded?}
          current_user={@current_user}
          current_team={@current_team}
          limit={@site_limit}
          resource="sites"
        />

        <.input
          help_text="Just the naked domain or subdomain without 'www', 'https' etc."
          type="text"
          placeholder="example.com"
          field={f[:domain]}
          label="Domain"
          disabled={@site_limit_exceeded?}
          mt?={false}
          autofocus="autofocus"
        />

        <input type="hidden" name={f[:timezone].name} id="tz-input" value="Etc/UTC" />
        <script>
          if (typeof Intl !== "undefined") {
            var detectedTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
            if (detectedTimezone) {
              document.getElementById("tz-input").value = detectedTimezone;
            }
          }
        </script>

        <div class="flex justify-end items-center gap-x-2">
          <.button_link theme="ghost" href={@back_button_href} mt?={false}>
            {@back_button_text}
          </.button_link>
          <.button
            disabled={@site_limit_exceeded?}
            type="submit"
            mt?={false}
            class="disabled:cursor-not-allowed"
          >
            Add site
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  def heading_and_subtitle(assigns) do
    ~H"""
    <div class="w-full max-w-md mx-auto mt-10 sm:mt-16 px-4 flex flex-col gap-y-2 dark:text-gray-300">
      <h1 class="text-lg sm:text-xl font-semibold">{@heading}</h1>
      <p class="text-base text-gray-500 dark:text-gray-400 text-pretty">
        {@subtitle}
      </p>
    </div>
    """
  end
end
