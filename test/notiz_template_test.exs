defmodule Zukunftslabor.NotizTemplateTest do
  use ExUnit.Case

  alias Zukunftslabor.NotizTemplate

  test "generate creates a markdown file with TOML frontmatter" do
    # Use a temp dir
    tmp = System.tmp_dir!()
    drafts = Path.join(tmp, "zukunftslabor_test_drafts")
    File.rm_rf!(drafts)

    # Temporarily override output dir
    path = NotizTemplate.generate(
      title: "Test Notiz",
      description: "A test notiz for verification.",
      slug: "test-notiz",
      category: "datenbriefing",
      evidence: "mittel",
      tags: ["test"],
      summary: "This is a test summary.",
      body: "## Test\n\nTest body content."
    )

    assert File.exists?(path)
    content = File.read!(path)

    # Check TOML frontmatter
    assert content =~ "+++"
    assert content =~ ~s(title = "Test Notiz")
    assert content =~ ~s(category = "datenbriefing")
    assert content =~ ~s(evidence = "mittel")
    assert content =~ ~s(tags = ["test"])

    # Check body
    assert content =~ "This is a test summary."
    assert content =~ "<!-- more -->"
    assert content =~ "## Test"

    # Cleanup
    File.rm_rf!(drafts)
  end
end
