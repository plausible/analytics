defmodule Plausible.Auth.SuperAdmin do
  def is?(nil), do: false
  def is?(%Plausible.Auth.User{id: id}), do: is?(id)

  def is?(user_id) when is_integer(user_id) do
    user_id in Application.get_env(:plausible, :super_admin_user_ids)
  end
end
