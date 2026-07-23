defmodule Plausible.Workers.OAuthCleanupTest do
  use Plausible.DataCase, async: true

  alias Plausible.OAuth.{AccessToken, AuthorizationCode, Token}
  alias Plausible.Workers.OAuthCleanup

  test "purges expired authorization codes and fully-expired tokens" do
    user = new_user()
    {:ok, team} = Plausible.Teams.get_or_create(user)
    now = DateTime.utc_now()

    code = Token.generate(:code)

    Repo.insert!(
      AuthorizationCode.changeset(%{
        code_hash: code.hash,
        client_id: "https://client.example/meta",
        redirect_uri: "https://client.example/cb",
        code_challenge: "x",
        code_challenge_method: "S256",
        user_id: user.id,
        team_id: team.id,
        expires_at: DateTime.add(now, -60, :second)
      })
    )

    token = Token.generate(:access)

    Repo.insert!(
      AccessToken.changeset(%{
        access_token_hash: token.hash,
        access_token_prefix: token.prefix,
        client_id: "https://client.example/meta",
        user_id: user.id,
        team_id: team.id,
        access_token_expires_at: DateTime.add(now, -120, :second),
        refresh_token_expires_at: DateTime.add(now, -60, :second)
      })
    )

    assert :ok = OAuthCleanup.perform(%Oban.Job{})
    assert Repo.aggregate(AuthorizationCode, :count) == 0
    assert Repo.aggregate(AccessToken, :count) == 0
  end
end
