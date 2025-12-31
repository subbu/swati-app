defmodule Swati.Repo do
  use Ecto.Repo,
    otp_app: :swati,
    adapter: Ecto.Adapters.SQLite3
end
