defmodule Swati.Avatars.Storage do
  def store_from_url(agent_id, source_url) when is_binary(source_url) do
    response =
      Req.get!(source_url,
        decode_body: false,
        receive_timeout: 30_000
      )

    extension = extension_from_headers(response.headers)
    filename = "avatar-#{Ecto.UUID.generate()}.#{extension}"
    dir = Path.join([base_path(), "agents", agent_id])

    File.mkdir_p!(dir)

    path = Path.join(dir, filename)
    File.write!(path, response.body)

    {:ok, %{path: path, public_url: public_url(path)}}
  rescue
    exception -> {:error, exception}
  end

  defp base_path do
    Application.get_env(:swati, :uploads_base_path, Path.expand("priv/static/uploads"))
  end

  defp public_base do
    Application.get_env(:swati, :uploads_public_path, "/uploads")
  end

  defp public_url(path) do
    relative = Path.relative_to(path, base_path())
    Path.join(public_base(), relative) |> String.replace("\\", "/")
  end

  defp extension_from_headers(headers) do
    content_type = content_type(headers)

    cond do
      is_binary(content_type) and String.contains?(content_type, "png") -> "png"
      is_binary(content_type) and String.contains?(content_type, "jpeg") -> "jpg"
      is_binary(content_type) and String.contains?(content_type, "jpg") -> "jpg"
      true -> "png"
    end
  end

  defp content_type(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(key) == "content-type", do: value
    end)
  end
end
