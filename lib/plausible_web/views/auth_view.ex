defmodule PlausibleWeb.AuthView do
  use PlausibleWeb, :view

  @subscription_names %{
    "558018" => "Personal",
    "558156" => "Personal (T)"
  }

  def subscription_name(subscription) do
    @subscription_names[subscription.paddle_plan_id]
  end
end
