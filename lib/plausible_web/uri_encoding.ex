defmodule PlausibleWeb.URIEncoding do
  # These characters are not URL encoded to have more readable URLs.
  # Browsers seem to handle this just fine. `?f=is,page,/my/page/:some_param`
  # vs `?f=is,page,%2Fmy%2Fpage%2F%3Asome_param`
  @do_not_url_encode [":", "/"]
  @do_not_url_encode_map Enum.into(@do_not_url_encode, %{}, fn char ->
                           {URI.encode_www_form(char), char}
                         end)

  def uri_encode_permissive(input) do
    input
    |> URI.encode_www_form()
    |> String.replace(Map.keys(@do_not_url_encode_map), &@do_not_url_encode_map[&1])
  end
end
