defmodule Swati.Scripts.PlivoBangaloreNumbers do
  def run do
    Mix.Task.run("app.start")

    args = System.argv()

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        switches: [
          output: :string,
          city: :string,
          country_iso: :string,
          type: :string,
          limit: :integer,
          region_city: :string,
          pattern: :string
        ]
      )

    output_path = Keyword.get(opts, :output, "plivo_bangalore_numbers.csv")

    params =
      %{
        "country_iso" => Keyword.get(opts, :country_iso, "IN"),
        "limit" => Keyword.get(opts, :limit, 20)
      }
      |> maybe_put("region_city", Keyword.get(opts, :region_city, "Bangalore"))
      |> maybe_put("city", Keyword.get(opts, :city))
      |> maybe_put("type", Keyword.get(opts, :type))
      |> maybe_put("pattern", Keyword.get(opts, :pattern))

    case fetch_all_numbers(params) do
      {:ok, numbers} ->
        write_csv(output_path, numbers)
        IO.puts("wrote #{length(numbers)} numbers to #{output_path}")

      {:error, reason} ->
        IO.puts(:stderr, "error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp fetch_all_numbers(params) do
    do_fetch(params, 0, [])
  end

  defp do_fetch(params, offset, acc) do
    params = Map.put(params, "offset", offset)

    case Swati.Telephony.search_available_numbers(params) do
      {:ok, response} when is_map(response) ->
        numbers = normalize_available_numbers(response)
        meta = normalize_meta(response)
        new_acc = acc ++ numbers

        if meta.total_count > offset + meta.limit do
          do_fetch(params, offset + meta.limit, new_acc)
        else
          {:ok, new_acc}
        end

      {:ok, _} ->
        {:ok, acc}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_available_numbers(response) when is_map(response) do
    objects =
      Map.get(response, "objects") || Map.get(response, :objects) ||
        Map.get(response, "numbers") || Map.get(response, :numbers) || []

    Enum.map(List.wrap(objects), &normalize_available_number/1)
  end

  defp normalize_available_number(object) when is_map(object) do
    %{
      number: fetch_value(object, ["number", :number]),
      country: fetch_value(object, ["country", :country]),
      region: fetch_value(object, ["region", :region]),
      city: fetch_value(object, ["city", :city]),
      type: fetch_value(object, ["type", :type]),
      sub_type: fetch_value(object, ["sub_type", :sub_type]),
      monthly_rental_rate: fetch_value(object, ["monthly_rental_rate", :monthly_rental_rate]),
      setup_rate: fetch_value(object, ["setup_rate", :setup_rate]),
      voice_enabled: fetch_value(object, ["voice_enabled", :voice_enabled]),
      sms_enabled: fetch_value(object, ["sms_enabled", :sms_enabled]),
      mms_enabled: fetch_value(object, ["mms_enabled", :mms_enabled]),
      restriction: fetch_value(object, ["restriction", :restriction]),
      restriction_text: fetch_value(object, ["restriction_text", :restriction_text])
    }
  end

  defp normalize_available_number(_), do: %{}

  defp normalize_meta(response) when is_map(response) do
    meta = Map.get(response, "meta") || Map.get(response, :meta) || %{}

    %{
      limit: to_int(Map.get(meta, "limit") || Map.get(meta, :limit), 10),
      offset: to_int(Map.get(meta, "offset") || Map.get(meta, :offset), 0),
      total_count: to_int(Map.get(meta, "total_count") || Map.get(meta, :total_count), 0)
    }
  end

  defp normalize_meta(_), do: %{limit: 10, offset: 0, total_count: 0}

  defp to_int(nil, default), do: default

  defp to_int(value, _default) when is_integer(value), do: value

  defp to_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp to_int(_, default), do: default

  defp maybe_put(params, _key, nil), do: params

  defp maybe_put(params, _key, ""), do: params

  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  defp fetch_value(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.get(map, key) do
        nil -> nil
        value -> value
      end
    end)
  end

  defp write_csv(path, numbers) do
    header = [
      "number",
      "country",
      "region",
      "city",
      "type",
      "sub_type",
      "monthly_rental_rate",
      "setup_rate",
      "voice_enabled",
      "sms_enabled",
      "mms_enabled",
      "restriction",
      "restriction_text"
    ]

    rows = Enum.map(numbers, &row_for_number/1)

    contents =
      [header | rows]
      |> Enum.map(&encode_csv_row/1)
      |> Enum.join("\n")

    File.write!(path, contents <> "\n")
  end

  defp row_for_number(number) do
    [
      number.number,
      number.country,
      number.region,
      number.city,
      number.type,
      number.sub_type,
      number.monthly_rental_rate,
      number.setup_rate,
      number.voice_enabled,
      number.sms_enabled,
      number.mms_enabled,
      number.restriction,
      number.restriction_text
    ]
  end

  defp encode_csv_row(values) do
    values
    |> Enum.map(&encode_csv_field/1)
    |> Enum.join(",")
  end

  defp encode_csv_field(nil), do: ""

  defp encode_csv_field(value) when is_boolean(value) do
    if value, do: "true", else: "false"
  end

  defp encode_csv_field(value) do
    value = to_string(value)

    if String.contains?(value, [",", "\n", "\r", "\""]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end
end

Swati.Scripts.PlivoBangaloreNumbers.run()
