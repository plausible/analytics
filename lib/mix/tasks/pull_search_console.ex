defmodule Mix.Tasks.PullSearchConsole do
  @client_id "1067516560281-9ugr4iijgr3uge3j6qir5n131me0o42o.apps.googleusercontent.com"
  @client_secret "aeeswPFIzagXeN4Q7a3IQ8aB"
  @oauth_scope "https://www.googleapis.com/auth/webmasters.readonly"
  @redirect_uri "https://plausible.io/auth/google/callback"

  @authorize_url "https://accounts.google.com/o/oauth2/v2/auth?client_id=1067516560281-9ugr4iijgr3uge3j6qir5n131me0o42o.apps.googleusercontent.com&redirect_uri=https%3A%2F%2Fplausible.io%2Fauth%2Fgoogle%2Fcallback&response_type=code&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fwebmasters.readonly"
  @access_token "ya29.GlxJB6n-U7fPSRNrhPI6AFw617T0oEJ4xSrt6uQOUJnih-fDJaUzQ9rlC4Yt6ncqmHLYJm_60hwoZkjGbbZ5JUnBHnvErRmK2mrUnh3pabQTAu1RCLV8SVkemKdPfQ"

  def run(args \\ []) do
    Application.ensure_all_started(:plausible)

    #IO.puts(@authorize_url)
    #code = IO.gets("Enter the code:")
    #token = HTTPoison.post!("https://www.googleapis.com/oauth2/v4/token", "client_id=1067516560281-9ugr4iijgr3uge3j6qir5n131me0o42o.apps.googleusercontent.com&client_secret=aeeswPFIzagXeN4Q7a3IQ8aB&code=#{code}&grant_type=authorization_code&redirect_uri=https%3A%2F%2Fplausible.io%2Fauth%2Fgoogle%2Fcallback", ["Content-Type": "application/x-www-form-urlencoded"])
    #IO.inspect(token)

    res = HTTPoison.post!("https://www.googleapis.com/webmasters/v3/sites/https%3A%2F%2Fplausible.io/searchAnalytics/query", Jason.encode!(%{
      startDate: "2019-06-16",
      endDate: "2019-07-16",
      dimensions: ["query"]
    }), ["Content-Type": "application/json", "Authorization": "Bearer #{@access_token}"])
    Jason.decode!(res.body) |> IO.inspect
  end
end
