defmodule Plausible.Repo.Migrations.RemoveTweets do
  use Ecto.Migration

  def change do
    drop table(:tweets)
  end
end
