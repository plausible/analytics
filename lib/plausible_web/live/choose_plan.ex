defmodule PlausibleWeb.Live.ChoosePlan do
  use Phoenix.LiveView
  use Phoenix.HTML

  def mount(_params, %{"user_id" => user_id}, socket) do
    user = Plausible.Users.with_subscription(user_id)

    {:ok, assign(socket, user: user)}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-green-300">
      Just a placeholder in this commit <%= @user.email %>
    </div>
    """
  end
end
