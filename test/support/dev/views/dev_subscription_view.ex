defmodule PlausibleWeb.DevSubscriptionView do
  use Plausible

  on_ee do
    use Phoenix.View,
      root: "test/support/dev/templates"

    use PlausibleWeb.VerifiedRoutes

    require Plausible.Billing.Subscription.Status
    import PlausibleWeb.Components.Generic
  end
end
