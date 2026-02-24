defmodule Swati.Channels.WhatsApp.PayloadBuilder do
  alias Swati.Channels.WhatsApp

  @template_categories ~w(UTILITY MARKETING AUTHENTICATION)

  def build_send_payload(attrs) when is_map(attrs) do
    if is_map(Map.get(attrs, "template") || Map.get(attrs, :template)) do
      build_template_send_payload(attrs)
    else
      build_text_payload(attrs)
    end
  end

  def build_text_payload(attrs) when is_map(attrs) do
    to = Map.get(attrs, "to") || Map.get(attrs, :to)
    text = Map.get(attrs, "text") || Map.get(attrs, :text)

    with {:ok, to_value} <- normalize_to_digits(to),
         :ok <- validate_non_empty(text) do
      {:ok,
       %{
         "messaging_product" => "whatsapp",
         "to" => to_value,
         "type" => "text",
         "text" => %{"body" => to_string(text)}
       }}
    end
  end

  def build_template_send_payload(attrs) when is_map(attrs) do
    to = Map.get(attrs, "to") || Map.get(attrs, :to)

    with {:ok, to_value} <- normalize_to_digits(to),
         {:ok, template} <-
           normalize_template(Map.get(attrs, "template") || Map.get(attrs, :template)) do
      {:ok,
       %{
         "messaging_product" => "whatsapp",
         "to" => to_value,
         "type" => "template",
         "template" => template
       }}
    end
  end

  def build_template_create_payload(attrs) when is_map(attrs) do
    with {:ok, name} <- normalize_template_name(Map.get(attrs, "name") || Map.get(attrs, :name)),
         {:ok, language} <-
           normalize_language(Map.get(attrs, "language") || Map.get(attrs, :language)),
         {:ok, category} <-
           normalize_category(Map.get(attrs, "category") || Map.get(attrs, :category)),
         {:ok, body_text} <-
           validate_non_empty(Map.get(attrs, "body_text") || Map.get(attrs, :body_text)) do
      header_text = Map.get(attrs, "header_text") || Map.get(attrs, :header_text)
      footer_text = Map.get(attrs, "footer_text") || Map.get(attrs, :footer_text)

      body_examples =
        parse_examples(
          Map.get(attrs, "body_example_values") || Map.get(attrs, :body_example_values)
        )

      components =
        []
        |> maybe_add_header_component(header_text)
        |> add_body_component(body_text, body_examples)
        |> maybe_add_footer_component(footer_text)

      {:ok,
       %{
         "name" => name,
         "language" => language,
         "category" => category,
         "components" => components
       }}
    end
  end

  defp normalize_to_digits(to) do
    normalized = WhatsApp.normalize_phone_number(to)

    case normalized do
      nil -> {:error, :message_payload_invalid}
      value -> {:ok, String.trim_leading(value, "+")}
    end
  end

  defp normalize_template(template) when is_map(template) do
    with {:ok, name} <- validate_non_empty(Map.get(template, "name") || Map.get(template, :name)),
         {:ok, language_code} <-
           normalize_language_code(
             get_in(template, ["language", "code"]) || get_in(template, [:language, :code]) ||
               Map.get(template, "language") || Map.get(template, :language)
           ) do
      components =
        template
        |> Map.get("components", Map.get(template, :components, []))
        |> normalize_components()

      normalized = %{
        "name" => to_string(name),
        "language" => %{"code" => language_code}
      }

      normalized =
        if components == [], do: normalized, else: Map.put(normalized, "components", components)

      {:ok, normalized}
    end
  end

  defp normalize_template(_), do: {:error, :message_payload_invalid}

  defp normalize_components(components) when is_list(components) do
    components
    |> Enum.map(&normalize_component/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_components(_), do: []

  defp normalize_component(component) when is_map(component) do
    type = Map.get(component, "type") || Map.get(component, :type)

    params =
      component
      |> Map.get("parameters", Map.get(component, :parameters, []))
      |> normalize_parameters()

    if is_binary(type) and params != [] do
      %{"type" => String.downcase(type), "parameters" => params}
    else
      nil
    end
  end

  defp normalize_component(_), do: nil

  defp normalize_parameters(parameters) when is_list(parameters) do
    parameters
    |> Enum.map(fn parameter ->
      ptype = Map.get(parameter, "type") || Map.get(parameter, :type) || "text"
      text = Map.get(parameter, "text") || Map.get(parameter, :text)

      if is_binary(text) and String.trim(text) != "" do
        %{"type" => String.downcase(to_string(ptype)), "text" => text}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_parameters(_), do: []

  defp normalize_template_name(name) do
    normalized =
      name
      |> to_string_or_empty()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9_]/, "_")
      |> String.replace(~r/_+/, "_")
      |> String.trim("_")

    if normalized == "" do
      {:error, :template_name_invalid}
    else
      {:ok, normalized}
    end
  end

  defp normalize_language(language) do
    with {:ok, code} <- normalize_language_code(language) do
      {:ok, code}
    end
  end

  defp normalize_language_code(language) do
    value = to_string_or_empty(language)

    if value == "" do
      {:error, :template_language_invalid}
    else
      {:ok, value}
    end
  end

  defp normalize_category(category) do
    normalized =
      category
      |> to_string_or_empty()
      |> String.upcase()

    if normalized in @template_categories do
      {:ok, normalized}
    else
      {:error, :template_category_invalid}
    end
  end

  defp maybe_add_header_component(components, header_text) do
    if text_present?(header_text) do
      components ++
        [%{"type" => "HEADER", "format" => "TEXT", "text" => String.trim(header_text)}]
    else
      components
    end
  end

  defp add_body_component(components, body_text, examples) do
    body = %{"type" => "BODY", "text" => String.trim(to_string(body_text))}

    body =
      if examples == [] do
        body
      else
        Map.put(body, "example", %{"body_text" => [examples]})
      end

    components ++ [body]
  end

  defp maybe_add_footer_component(components, footer_text) do
    if text_present?(footer_text) do
      components ++ [%{"type" => "FOOTER", "text" => String.trim(footer_text)}]
    else
      components
    end
  end

  defp parse_examples(nil), do: []
  defp parse_examples([]), do: []

  defp parse_examples(examples) when is_list(examples) do
    examples
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_examples(examples) when is_binary(examples) do
    examples
    |> String.split(",")
    |> parse_examples()
  end

  defp parse_examples(_), do: []

  defp validate_non_empty(value) do
    value = to_string_or_empty(value)

    if value == "" do
      {:error, :message_payload_invalid}
    else
      {:ok, value}
    end
  end

  defp to_string_or_empty(nil), do: ""

  defp to_string_or_empty(value) do
    value
    |> to_string()
    |> String.trim()
  end

  defp text_present?(value), do: to_string_or_empty(value) != ""
end
