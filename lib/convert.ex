defmodule Convert do
  def convert() do
    Path.wildcard("fixture/vcr_cassettes/*.json")
    |> Enum.each(fn f ->
      IO.puts("Processing #{f}")
      decoded = File.read!(f) |> Jason.decode!()

      list =
        Enum.map(decoded, fn el ->
          request_body =
            case Jason.decode(el["request"]["body"]) do
              {:ok, body} -> body
              {:error, _} -> URI.decode_query(el["request"]["body"])
            end

          url = el["request"]["url"]
          method = el["request"]["method"]
          response_body = el["response"]["body"] |> Jason.decode!()
          status = el["response"]["status_code"]

          %{
            request_body: request_body,
            status: status,
            url: url,
            method: method,
            response_body: response_body
          }
        end)

      File.write!(
        "fixture/http_mocks/#{Path.basename(f)}",
        Jason.encode!(list, pretty: true)
      )
      |> IO.inspect(label: :done)
    end)
  end
end

# Convert.convert()
