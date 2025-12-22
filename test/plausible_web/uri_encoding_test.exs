defmodule PlausibleWeb.URIEncodingTest do
  use ExUnit.Case, async: true

  for {value, expected} <- [
        {"/:dashboard/settings", "/:dashboard/settings"},
        {"&", "%26"},
        {"=", "%3D"},
        {",", "%2C"},
        # should be {"hello world", "hello%20world"}, is
        {"hello world", "hello+world"}
      ] do
    test "permissively uri-encoding value #{inspect(value)} yields #{inspect(expected)}" do
      assert PlausibleWeb.URIEncoding.uri_encode_permissive(unquote(value)) == unquote(expected)
    end
  end
end
