defmodule PlausibleWeb.AuthView do
  use PlausibleWeb, :view

  @subscription_names %{
    "558018" => "Personal",
    "558156" => "Personal (T)",
    "558199" => "Startup (T)",
    "558200" => "Business (T)"
  }

  def subscription_name(subscription) do
    @subscription_names[subscription.paddle_plan_id]
  end
end
