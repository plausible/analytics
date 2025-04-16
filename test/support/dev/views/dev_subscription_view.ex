defmodule PlausibleWeb.DevSubscriptionView do
  use Phoenix.View,
    root: "test/support/dev/templates"

  require Plausible.Billing.Subscription.Status
  import PlausibleWeb.Components.Generic
  alias PlausibleWeb.Router.Helpers, as: Routes
end
