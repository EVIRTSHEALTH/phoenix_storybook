defmodule Mix.Tasks.Storybook.Markdown do
  @shortdoc "Generates a markdown file listing all storybook components"
  @moduledoc """
  Generates a markdown file with one line per component story.

  ```bash
  $> mix storybook.markdown MyAppWeb.Storybook
  $> mix storybook.markdown MyAppWeb.Storybook --output custom.md
  ```

  Each line follows the format:
  `.component_name component_file_path component_description`

  For example:
  `.input lib/my_app_web/components/core_components.ex input handler for every html input type`
  """

  use Mix.Task

  @requirements ["app.config"]
  @switches [output: :string]
  @aliases [o: :output]

  @doc false
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, args, _} = OptionParser.parse(argv, strict: @switches, aliases: @aliases)

    backend_module =
      case args do
        [module_name] -> Module.concat([module_name])
        [] -> Mix.raise("Backend module required. Usage: mix storybook.markdown MyAppWeb.Storybook")
        _ -> Mix.raise("Too many arguments. Usage: mix storybook.markdown MyAppWeb.Storybook")
      end

    output_path = Keyword.get(opts, :output, "storybook.md")

    # Ensure the backend module is loaded
    Code.ensure_compiled!(backend_module)

    Mix.shell().info("Generating markdown from #{inspect(backend_module)}...")

    # Get all story entries
    entries = backend_module.leaves()

    # Generate markdown lines
    lines =
      entries
      |> Enum.map(&process_story(backend_module, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()

    # Write to file
    content = Enum.join(lines, "\n") <> "\n"
    File.write!(output_path, content)

    Mix.shell().info("Generated #{length(lines)} entries in #{output_path}")
  end

  defp process_story(backend_module, entry) do
    case backend_module.load_story(entry.path) do
      {:ok, story} ->
        # Only process component and live_component stories
        case story.storybook_type() do
          type when type in [:component, :live_component] ->
            generate_line(entry, story)

          _ ->
            nil
        end

      {:error, _, _} ->
        Mix.shell().error("Failed to load story: #{entry.path}")
        nil
    end
  end

  defp generate_line(entry, story) do
    name = extract_name(entry.path)
    path = extract_component_path(story)
    doc = extract_doc(story)

    ".#{name} #{path} #{doc}"
  end

  defp extract_name(path) do
    path
    |> String.replace_prefix("/", "")
    |> String.split("/")
    |> List.last()
  end

  defp extract_component_path(story) do
    module =
      case story.storybook_type() do
        :component ->
          # Extract module from function
          function = story.function()
          info = Function.info(function)
          info[:module]

        :live_component ->
          # Direct module reference
          story.component()
      end

    case :code.which(module) do
      path when is_list(path) ->
        path
        |> to_string()
        |> String.replace_prefix(File.cwd!() <> "/", "")

      :non_existing ->
        "unknown"

      _ ->
        "unknown"
    end
  end

  defp extract_doc(story) do
    case story.doc() do
      nil ->
        ""

      %{header: header, body: body} ->
        # Doc struct with header and body
        ([header, body] |> Enum.reject(&is_nil/1) |> Enum.join(" "))
        |> strip_html()
        |> String.replace("\n", " ")
        |> String.trim()

      doc when is_binary(doc) ->
        doc
        |> strip_html()
        |> String.replace("\n", " ")
        |> String.trim()

      doc when is_list(doc) ->
        doc
        |> Enum.join(" ")
        |> strip_html()
        |> String.replace("\n", " ")
        |> String.trim()
    end
  end

  defp strip_html(html) do
    html
    |> String.replace(~r/<[^>]*>/, "")
    |> decode_html_entities()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp decode_html_entities(text) do
    text
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.replace("&amp;", "&")
  end
end
