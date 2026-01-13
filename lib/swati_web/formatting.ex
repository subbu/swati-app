defmodule SwatiWeb.Formatting do
  @moduledoc false

  @default_locale "en-IN"
  @default_phone_country "IN"

  @locale_formats %{
    "en-IN" => %{
      date: "%-d %b, %Y",
      datetime: "%H:%M %-d %b, %Y",
      datetime_short: "%H:%M %-d %b",
      datetime_long: "%I:%M %p %-d %b, %Y"
    },
    "en-US" => %{
      date: "%b %-d, %Y",
      datetime: "%I:%M %p %b %-d, %Y",
      datetime_short: "%I:%M %p %b %-d",
      datetime_long: "%I:%M %p %b %-d, %Y"
    },
    "en-GB" => %{
      date: "%-d %b, %Y",
      datetime: "%H:%M %-d %b, %Y",
      datetime_short: "%H:%M %-d %b",
      datetime_long: "%H:%M %-d %b, %Y"
    }
  }

  def date(%DateTime{} = dt, tenant) do
    Calendar.strftime(dt, format_pattern(tenant, :date))
  end

  def datetime(%DateTime{} = dt, tenant) do
    Calendar.strftime(dt, format_pattern(tenant, :datetime))
  end

  def datetime_short(%DateTime{} = dt, tenant) do
    Calendar.strftime(dt, format_pattern(tenant, :datetime_short))
  end

  def datetime_long(%DateTime{} = dt, tenant) do
    Calendar.strftime(dt, format_pattern(tenant, :datetime_long))
  end

  def phone(nil, _tenant), do: nil
  def phone("", _tenant), do: nil

  def phone(value, tenant) do
    number =
      value
      |> to_string()
      |> String.trim()

    if number == "" do
      nil
    else
      format_phone(number, tenant)
    end
  end

  defp format_phone(number, tenant) do
    digits = String.replace(number, ~r/[^0-9]/, "")
    prefix = if String.starts_with?(number, "+"), do: "+", else: ""

    case phone_country(tenant) do
      "IN" -> format_india_number(prefix, digits)
      "US" -> format_nanp_number(prefix, digits)
      "CA" -> format_nanp_number(prefix, digits)
      _ -> format_number_fallback(prefix, digits)
    end
  end

  defp format_india_number(prefix, digits) do
    if String.length(digits) == 12 and String.starts_with?(digits, "91") do
      country = String.slice(digits, 0, 2)
      area = String.slice(digits, 2, 2)
      block1 = String.slice(digits, 4, 4)
      block2 = String.slice(digits, 8, 4)
      "+#{country} #{area} #{block1} #{block2}"
    else
      format_number_fallback(prefix, digits)
    end
  end

  defp format_nanp_number(prefix, digits) do
    cond do
      String.length(digits) == 11 and String.starts_with?(digits, "1") ->
        country = String.slice(digits, 0, 1)
        area = String.slice(digits, 1, 3)
        exchange = String.slice(digits, 4, 3)
        line = String.slice(digits, 7, 4)
        "#{prefix}#{country} #{area} #{exchange} #{line}"

      String.length(digits) == 10 ->
        area = String.slice(digits, 0, 3)
        exchange = String.slice(digits, 3, 3)
        line = String.slice(digits, 6, 4)
        "#{prefix}#{area} #{exchange} #{line}"

      true ->
        format_number_fallback(prefix, digits)
    end
  end

  defp format_number_fallback(prefix, digits) do
    if String.length(digits) <= 4 do
      prefix <> digits
    else
      {rest, last4} = String.split_at(digits, -4)
      groups = chunk_from_right(rest, 3)

      [prefix <> Enum.join(groups, " "), last4]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")
    end
  end

  defp chunk_from_right(value, size) do
    value
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(size)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map(&Enum.join/1)
  end

  defp format_pattern(tenant, key) do
    config = formatting_config(tenant)
    override = format_override(config, key)

    cond do
      is_binary(override) and override != "" ->
        override

      true ->
        locale = locale(config)
        formats = Map.get(@locale_formats, locale, @locale_formats[@default_locale])
        Map.fetch!(formats, key)
    end
  end

  defp format_override(config, :date),
    do: fetch_config(config, "date_format", :date_format)

  defp format_override(config, :datetime),
    do: fetch_config(config, "datetime_format", :datetime_format)

  defp format_override(config, :datetime_short),
    do: fetch_config(config, "datetime_short_format", :datetime_short_format)

  defp format_override(config, :datetime_long),
    do: fetch_config(config, "datetime_long_format", :datetime_long_format)

  defp locale(config) do
    value = fetch_config(config, "locale", :locale)

    if is_binary(value) and value != "" do
      value
    else
      @default_locale
    end
  end

  defp phone_country(tenant) do
    config = formatting_config(tenant)
    value = fetch_config(config, "phone_country", :phone_country)

    cond do
      is_binary(value) and value != "" ->
        value

      true ->
        locale(config)
        |> derive_phone_country()
        |> default_phone_country()
    end
  end

  defp derive_phone_country(locale) when is_binary(locale) do
    case String.split(locale, "-", parts: 2) do
      [_lang, region] -> region
      _ -> nil
    end
  end

  defp default_phone_country(nil), do: @default_phone_country
  defp default_phone_country(country), do: country

  defp formatting_config(%{formatting: formatting}) when is_map(formatting), do: formatting
  defp formatting_config(_tenant), do: %{}

  defp fetch_config(config, key, atom_key) when is_map(config) do
    cond do
      Map.has_key?(config, key) -> Map.get(config, key)
      Map.has_key?(config, atom_key) -> Map.get(config, atom_key)
      true -> nil
    end
  end
end
