defmodule Plausible.Workers.OAuthCleanup do
  @moduledoc """
  Periodically purges expired OAuth authorization codes and fully-expired
  access/refresh token rows.
  """

  use Oban.Worker, queue: :oauth_cleanup

  @impl Oban.Worker
  def perform(_job) do
    Plausible.OAuth.delete_expired()
    :ok
  end
end
