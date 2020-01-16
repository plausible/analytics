defmodule Plausible.Twitter.Tweet do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:link, :tweet_id, :author_handle, :author_name, :author_image, :text, :created]

  @derive {Jason.Encoder, only: @required_fields}
  schema "tweets" do
    field :link, :string

    field :tweet_id, :string
    field :author_handle, :string
    field :author_name, :string
    field :author_image, :string
    field :text, :string
    field :created, :naive_datetime, null: false

    timestamps()
  end

  def changeset(tweet, attrs) do
    tweet
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
  end
end
