defmodule Plausible.Repo.Migrations.AddTweets do
  use Ecto.Migration

  def change do
    create table(:tweets) do
      add :tweet_id, :text, null: false
      add :text, :text, null: false
      add :author_handle, :text, null: false
      add :author_name, :text, null: false
      add :author_image, :text, null: false
      add :created, :naive_datetime, null: false
      add :link, :string, null: false

      timestamps()
    end

    create index(:tweets, :link)
    create unique_index(:tweets, [:link, :tweet_id])
  end
end
