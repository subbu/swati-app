defmodule Mix.Tasks.Swati.BackfillPhoneNumbers do
  use Mix.Task

  alias Swati.Repo
  alias Swati.Telephony.E164
  alias Swati.Telephony.PhoneNumber

  @shortdoc "Normalize phone_numbers.e164 values"

  @moduledoc """
  Normalizes phone_numbers.e164 values to +<digits> form.
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    result =
      Repo.transaction(fn ->
        PhoneNumber
        |> Repo.stream()
        |> Enum.reduce({0, 0, 0}, fn phone_number, {updated, skipped, conflicts} ->
          e164 = phone_number.e164

          if is_binary(e164) do
            %{normalized: normalized} = E164.normalize(e164)

            if normalized == e164 or normalized == "" do
              {updated, skipped + 1, conflicts}
            else
              case phone_number
                   |> PhoneNumber.changeset(%{e164: normalized})
                   |> Repo.update() do
                {:ok, _} -> {updated + 1, skipped, conflicts}
                {:error, _} -> {updated, skipped, conflicts + 1}
              end
            end
          else
            {updated, skipped + 1, conflicts}
          end
        end)
      end)

    case result do
      {:ok, {updated, skipped, conflicts}} ->
        Mix.shell().info(
          "phone_numbers backfill complete updated=#{updated} skipped=#{skipped} conflicts=#{conflicts}"
        )

      {:error, reason} ->
        Mix.raise("phone_numbers backfill failed reason=#{inspect(reason)}")
    end
  end
end
