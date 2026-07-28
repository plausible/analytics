defmodule PlausibleWeb.Live.OnboardingLayoutContext do
  @moduledoc false

  import Phoenix.Component

  alias PlausibleWeb.Flows

  def on_mount(_arg, params, _session, socket) do
    socket =
      assign(socket,
        hide_trial_badge?: params["flow"] == Flows.register(),
        hide_footer?: true,
        disable_global_notices?: true,
        white_bg?: true
      )

    {:cont, socket, layout: {PlausibleWeb.LayoutView, :onboarding}}
  end
end
