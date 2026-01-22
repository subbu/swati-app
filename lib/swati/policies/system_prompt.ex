defmodule Swati.Policies.SystemPrompt do
  alias Swati.Policies

  @spec compose(list(map() | nil)) :: %{prepend: [String.t()], append: [String.t()]}
  def compose(policies) when is_list(policies) do
    policies
    |> Enum.map(&layer_prompt/1)
    |> Enum.reduce(%{prepend: [], append: []}, &merge_layer/2)
  end

  defp layer_prompt(policy) do
    policy = Policies.normalize(policy)

    prompt =
      Map.get(policy, "system_prompt") ||
        Map.get(policy, :system_prompt) ||
        %{}

    %{
      prepend: normalize_blocks(Map.get(prompt, "prepend") || Map.get(prompt, :prepend)),
      append: normalize_blocks(Map.get(prompt, "append") || Map.get(prompt, :append))
    }
  end

  defp merge_layer(layer, acc) do
    %{
      prepend: acc.prepend ++ layer.prepend,
      append: acc.append ++ layer.append
    }
  end

  defp normalize_blocks(nil), do: []

  defp normalize_blocks(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> []
      text -> [text]
    end
  end

  defp normalize_blocks(value) when is_list(value) do
    value
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_blocks(_value), do: []
end
