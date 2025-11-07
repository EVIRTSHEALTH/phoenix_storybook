defmodule Mix.Tasks.Storybook.MarkdownTest do
  use ExUnit.Case
  alias Mix.Tasks.Storybook.Markdown

  setup do
    Mix.shell(Mix.Shell.Process)
    Mix.Task.clear()
    on_exit(fn -> File.rm("storybook.md") end)
    :ok
  end

  test "generates markdown file from storybook" do
    Markdown.run(["PhoenixStorybook.TreeStorybook"])

    assert_receive {:mix_shell, :info, ["Generating markdown from PhoenixStorybook.TreeStorybook..."]}
    assert_receive {:mix_shell, :info, [msg]}
    assert msg =~ ~r/Generated \d+ entries in storybook.md/

    assert File.exists?("storybook.md")
    content = File.read!("storybook.md")

    # Should contain component entries
    assert content =~ ".component"
    assert content =~ ".all_types_component"
    assert content =~ ".live_component"

    # Should not contain page entries (pages are filtered out)
    refute content =~ "APage"
    refute content =~ "BPage"

    # Each line should follow the format: .name path description
    lines = String.split(content, "\n", trim: true)
    assert length(lines) > 0

    for line <- lines do
      assert line =~ ~r/^\.\w+\s+\S+/
    end
  end

  test "generates markdown with custom output path" do
    Markdown.run(["PhoenixStorybook.TreeStorybook", "--output", "custom.md"])

    assert_receive {:mix_shell, :info, ["Generating markdown from PhoenixStorybook.TreeStorybook..."]}
    assert_receive {:mix_shell, :info, [msg]}
    assert msg =~ ~r/Generated \d+ entries in custom.md/

    assert File.exists?("custom.md")
    refute File.exists?("storybook.md")

    File.rm("custom.md")
  end

  test "fails when backend module is missing" do
    assert_raise Mix.Error, "Backend module required. Usage: mix storybook.markdown MyAppWeb.Storybook", fn ->
      Markdown.run([])
    end
  end

  test "fails when backend module does not exist" do
    assert_raise ArgumentError, ~r/could not load module/, fn ->
      Markdown.run(["NonExistent.Module"])
    end
  end

  test "markdown contains decoded HTML entities" do
    Markdown.run(["PhoenixStorybook.TreeStorybook"])

    content = File.read!("storybook.md")

    # Should have decoded HTML entities like <, >, ", etc.
    # The component docs contain examples with <.component ... />
    assert content =~ "<.component"
    refute content =~ "&lt;.component"
  end

  test "markdown contains component file paths" do
    Markdown.run(["PhoenixStorybook.TreeStorybook"])

    content = File.read!("storybook.md")

    # Should contain beam file paths
    assert content =~ ~r/\.beam/
    assert content =~ "Component.beam"
  end

  test "markdown filters out examples and pages" do
    Markdown.run(["PhoenixStorybook.TreeStorybook"])

    content = File.read!("storybook.md")
    lines = String.split(content, "\n", trim: true)

    # All lines should be components or live_components, not pages or examples
    # Pages would be in tree storybook as a_page and b_page
    # Examples would be in examples/example
    for line <- lines do
      # Extract the name (first word after the dot)
      [name | _] = String.split(line, " ")
      name = String.trim_leading(name, ".")

      # These are page/example names that should NOT appear
      refute name in ["a_page", "b_page", "example"]
    end
  end

  test "handles components with no documentation" do
    Markdown.run(["PhoenixStorybook.TreeStorybook"])

    content = File.read!("storybook.md")

    # Some components like nested_component have no doc
    # Should still generate a line with empty description
    assert content =~ ~r/\.nested_component\s+\S+\s*$/m
  end

  test "markdown entries are sorted alphabetically" do
    Markdown.run(["PhoenixStorybook.TreeStorybook"])

    content = File.read!("storybook.md")
    lines = String.split(content, "\n", trim: true)

    # Extract names
    names =
      Enum.map(lines, fn line ->
        [name | _] = String.split(line, " ")
        name
      end)

    assert names == Enum.sort(names)
  end
end
