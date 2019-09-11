defmodule PlausibleWeb.LayoutView do
  use PlausibleWeb, :view

  def trial_notificaton(user) do
    case Plausible.Billing.trial_days_left(user) do
      days when days > 1 ->
        "#{days} trial days left"
      days when days == 1 ->
        "Trial ends tomorrow"
      days when days == 0 ->
        "Trial ends today"
      days when days < 0 ->
        "Trial over, upgrade now"
    end
  end
end
