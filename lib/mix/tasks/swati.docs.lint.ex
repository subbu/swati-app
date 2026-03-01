defmodule Mix.Tasks.Swati.Docs.Lint do
  use Mix.Task

  @shortdoc "Validate the agent knowledge base layout under docs/."

  @required_files [
    "AGENTS.md",
    "ARCHITECTURE.md",
    "docs/README.md",
    "docs/DESIGN.md",
    "docs/PLANS.md",
    "docs/QUALITY_SCORE.md",
    "docs/RELIABILITY.md",
    "docs/SECURITY.md",
    "docs/design-docs/index.md",
    "docs/design-docs/core-beliefs.md",
    "docs/exec-plans/template.md",
    "docs/exec-plans/tech-debt-tracker.md",
    "docs/generated/db-schema.md",
    "docs/product-specs/index.md",
    "docs/references/index.md"
  ]

  @required_dirs [
    "docs/design-docs",
    "docs/exec-plans/active",
    "docs/exec-plans/completed",
    "docs/generated",
    "docs/product-specs",
    "docs/references"
  ]

  @impl Mix.Task
  def run(_args) do
    errors =
      []
      |> check_required_files()
      |> check_required_dirs()
      |> check_indexed("docs/design-docs", "docs/design-docs/index.md", exclude: ["index.md"])
      |> check_indexed("docs/references", "docs/references/index.md", exclude: ["index.md"])
      |> Enum.reverse()

    case errors do
      [] ->
        Mix.shell().info("docs lint OK")

      errors ->
        msg =
          [
            "docs lint failed:",
            Enum.map(errors, &("  - " <> &1))
          ]
          |> List.flatten()
          |> Enum.join("\n")

        Mix.raise(msg)
    end
  end

  defp check_required_files(errors) do
    Enum.reduce(@required_files, errors, fn path, acc ->
      if File.exists?(path) do
        acc
      else
        ["missing file: #{path}" | acc]
      end
    end)
  end

  defp check_required_dirs(errors) do
    Enum.reduce(@required_dirs, errors, fn path, acc ->
      if File.dir?(path) do
        acc
      else
        ["missing directory: #{path}" | acc]
      end
    end)
  end

  defp check_indexed(errors, dir, index_path, opts) do
    exclude = Keyword.get(opts, :exclude, [])

    index_text =
      case File.read(index_path) do
        {:ok, text} -> text
        {:error, _reason} -> nil
      end

    if is_binary(index_text) do
      dir
      |> list_markdown_files(exclude)
      |> Enum.reduce(errors, fn file, acc ->
        relative = Path.relative_to(file, dir)

        if String.contains?(index_text, relative) do
          acc
        else
          ["#{index_path} missing link to #{relative}" | acc]
        end
      end)
    else
      ["cannot read index file: #{index_path}" | errors]
    end
  end

  defp list_markdown_files(dir, exclude) do
    Path.join(dir, "**/*.md")
    |> Path.wildcard()
    |> Enum.reject(fn path ->
      rel = Path.relative_to(path, dir)
      rel in exclude
    end)
    |> Enum.sort()
  end
end
