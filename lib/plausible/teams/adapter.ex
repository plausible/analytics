defmodule Plausible.Teams.Adapter do
  @moduledoc """
  Commonly used teams-transition functions
  """
  alias Plausible.Teams

  defmacro __using__(_) do
    quote do
      alias Plausible.Teams
      import Teams.Adapter
    end
  end

  def user_or_team(user) do
    switch(user,
      team_fn: &Function.identity/1,
      user_fn: &Function.identity/1
    )
  end

  def switch(user, opts \\ []) do
    team_fn = Keyword.fetch!(opts, :team_fn)
    user_fn = Keyword.fetch!(opts, :user_fn)

    if Teams.read_team_schemas?(user) do
      team =
        case Teams.get_by_owner(user) do
          {:ok, team} -> team
          {:error, _} -> nil
        end

      team = Plausible.Teams.with_subscription(team)

      team_fn.(team)
    else
      user = Plausible.Users.with_subscription(user)
      user_fn.(user)
    end
  end
end
