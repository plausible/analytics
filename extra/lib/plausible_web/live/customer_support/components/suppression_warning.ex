defmodule PlausibleWeb.CustomerSupport.Components.SuppressionWarning do
  use Phoenix.Component
  use PlausibleWeb.VerifiedRoutes

  import PlausibleWeb.Components.Generic

  attr :email, :string, required: true
  attr :linked?, :boolean, default: true

  def suppression_warning(assigns) do
    assigns =
      assign(assigns, :suppressed?, Plausible.EmailSuppressions.suppressed?(assigns.email))

    ~H"""
    <.styled_link
      :if={@suppressed? && @linked?}
      patch={~p"/cs/email-suppressions?#{[search: @email]}"}
      title="This address is suppressed"
    >
      <Heroicons.exclamation_triangle solid class="w-4 h-4 text-yellow-500 inline" />
    </.styled_link>
    <Heroicons.exclamation_triangle
      :if={@suppressed? && !@linked?}
      solid
      class="w-4 h-4 text-yellow-500 inline"
      title="This address is suppressed"
    />
    """
  end
end
