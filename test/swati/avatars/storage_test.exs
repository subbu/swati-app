defmodule Swati.Avatars.StorageTest do
  use ExUnit.Case, async: true

  alias Swati.Avatars.Storage

  setup do
    keys = [
      :avatar_s3_bucket,
      :avatar_s3_region,
      :avatar_s3_access_key_id,
      :avatar_s3_secret_access_key,
      :avatar_s3_endpoint,
      :avatar_s3_public_base_url
    ]

    previous = Map.new(keys, fn key -> {key, Application.get_env(:swati, key)} end)

    Application.put_env(:swati, :avatar_s3_bucket, "bucket")
    Application.put_env(:swati, :avatar_s3_region, "eu-central")
    Application.put_env(:swati, :avatar_s3_access_key_id, "access-key")
    Application.put_env(:swati, :avatar_s3_secret_access_key, "secret-key")
    Application.put_env(:swati, :avatar_s3_endpoint, "https://example.com")
    Application.put_env(:swati, :avatar_s3_public_base_url, nil)

    on_exit(fn ->
      Enum.each(previous, fn {key, value} ->
        if is_nil(value) do
          Application.delete_env(:swati, key)
        else
          Application.put_env(:swati, key, value)
        end
      end)
    end)

    :ok
  end

  test "object_key uses bucket root and extension" do
    key = Storage.object_key("agent-id", "png")
    assert key =~ ~r/^avatar-[0-9a-f-]+\.png$/
  end

  test "public_url_for_key uses configured base with scheme" do
    Application.put_env(
      :swati,
      :avatar_s3_public_base_url,
      "hel1.your-objectstorage.com/subbu-dev-avatars"
    )

    assert Storage.public_url_for_key("avatar.png") ==
             "https://hel1.your-objectstorage.com/subbu-dev-avatars/avatar.png"
  end

  test "public_url_for_key falls back to endpoint and bucket" do
    Application.put_env(:swati, :avatar_s3_public_base_url, nil)
    Application.put_env(:swati, :avatar_s3_endpoint, "hel1.your-objectstorage.com")

    assert Storage.public_url_for_key("avatar.png") ==
             "https://hel1.your-objectstorage.com/bucket/avatar.png"
  end
end
