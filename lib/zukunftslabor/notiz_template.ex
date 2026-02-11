defmodule Zukunftslabor.NotizTemplate do
  @moduledoc """
  Generate notiz markdown drafts with TOML frontmatter matching
  the die-zukunft.ch `notiz.html` template requirements.
  """

  @doc """
  Generate a notiz draft markdown file.

  Options:
    - `:title` - page title (required)
    - `:description` - meta description for SEO (required)
    - `:slug` - URL slug (required)
    - `:category` - one of: datenbriefing, langforschung, standpunkt (required)
    - `:evidence` - one of: stark, mittel, schwach (required)
    - `:tags` - list of tag strings (required)
    - `:charts` - list of chart filenames (optional)
    - `:summary` - key finding summary paragraph (required)
    - `:body` - markdown body content (required)
    - `:date` - ISO date string, defaults to today

  Returns the output file path.
  """
  def generate(opts) do
    title = Keyword.fetch!(opts, :title)
    description = Keyword.fetch!(opts, :description)
    slug = Keyword.fetch!(opts, :slug)
    category = Keyword.fetch!(opts, :category)
    evidence = Keyword.fetch!(opts, :evidence)
    tags = Keyword.fetch!(opts, :tags)
    charts = Keyword.get(opts, :charts, [])
    summary = Keyword.fetch!(opts, :summary)
    body = Keyword.fetch!(opts, :body)
    date = Keyword.get(opts, :date, Date.utc_today() |> Date.to_iso8601())

    frontmatter = build_frontmatter(%{
      title: title,
      description: description,
      slug: slug,
      date: date,
      template: "notiz.html",
      category: category,
      evidence: evidence,
      tags: tags,
      charts: charts
    })

    content = """
    +++
    #{frontmatter}
    +++

    #{summary}

    <!-- more -->

    #{body}
    """
    |> String.trim_leading()

    dir = Zukunftslabor.drafts_dir()
    File.mkdir_p!(dir)
    path = Path.join(dir, "#{slug}.md")
    File.write!(path, content)

    IO.puts("Draft generated → #{path}")
    path
  end

  defp build_frontmatter(map) do
    lines = [
      ~s(title = "#{escape(map.title)}"),
      ~s(description = "#{escape(map.description)}"),
      ~s(slug = "#{map.slug}"),
      ~s(date = #{map.date}),
      ~s(template = "#{map.template}"),
      "",
      "[extra]",
      ~s(category = "#{map.category}"),
      ~s(evidence = "#{map.evidence}"),
      "tags = #{format_list(map.tags)}"
    ]

    lines = if map.charts != [] do
      lines ++ ["charts = #{format_list(map.charts)}"]
    else
      lines
    end

    Enum.join(lines, "\n")
  end

  defp format_list(items) do
    inner = items |> Enum.map(&~s("#{escape(&1)}")) |> Enum.join(", ")
    "[#{inner}]"
  end

  defp escape(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end
