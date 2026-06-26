module MarkdownHelper
  HINT_ICONS = { "info" => "bi-info-circle-fill", "warning" => "bi-exclamation-triangle-fill",
                 "danger" => "bi-x-octagon-fill", "success" => "bi-check-circle-fill" }.freeze
  HINT_COLORS = { "info" => "primary", "warning" => "warning", "danger" => "danger", "success" => "success" }.freeze

  # Rewrites chapter .md links to in-app help routes; external links open in new tab.
  class Renderer < Redcarpet::Render::HTML
    def link(link, title, content)
      if !link.start_with?("http", "mailto", "#") && link.end_with?(".md")
        chapter = File.basename(link, ".md")
        %(<a href="/help/inventario/#{chapter}" data-turbo-frame="help_panel_content">#{content}</a>)
      elsif link.start_with?("http")
        %(<a href="#{link}" target="_blank" rel="noopener">#{content}</a>)
      else
        %(<a href="#{link}">#{content}</a>)
      end
    end
  end

  def render_markdown(text)
    # Redcarpet's block-HTML parser gets confused by multi-line <div> blocks injected
    # mid-document — it stops processing markdown after them. Fix: replace every block
    # we'd generate (mermaid, hints, tabs) with a single-line placeholder BEFORE
    # Redcarpet runs, then substitute real HTML back into the rendered output.
    blocks = []

    text = extract_mermaid(text, blocks)
    text = extract_hints(text, blocks)
    text = extract_tabs(text, blocks)

    md     = Redcarpet::Markdown.new(Renderer.new(hard_wrap: false),
               tables: true, fenced_code_blocks: true,
               autolink: true, strikethrough: true, no_intra_emphasis: true)
    result = md.render(text)

    blocks.each_with_index do |html, idx|
      result.sub!("<div id=\"hb-#{idx}\"></div>", html)
    end

    result.html_safe
  end

  private

  def placeholder(blocks, html)
    idx = blocks.size
    blocks << html
    "\n\n<div id=\"hb-#{idx}\"></div>\n\n"
  end

  def extract_mermaid(text, blocks)
    text.gsub(/```mermaid\n(.*?)```/m) do
      placeholder(blocks, "<div class=\"help-mermaid\">#{$1.strip}</div>")
    end
  end

  def extract_hints(text, blocks)
    text.gsub(/\{%\s*hint style="(\w+)"\s*%\}(.*?)\{%\s*endhint\s*%\}/m) do
      style   = $1
      color   = HINT_COLORS[style] || "secondary"
      icon    = HINT_ICONS[style]  || "bi-info-circle-fill"
      body    = md_fragment($2.strip)
      html    = <<~HTML.strip
        <div class="help-hint help-hint--#{style} alert alert-#{color} d-flex gap-2 align-items-start">
          <i class="bi #{icon} flex-shrink-0 mt-1"></i>
          <div class="help-hint__body">#{body}</div>
        </div>
      HTML
      placeholder(blocks, html)
    end
  end

  def extract_tabs(text, blocks)
    text.gsub(/\{%\s*tabs\s*%\}(.*?)\{%\s*endtabs\s*%\}/m) do
      tabs = $1.scan(/\{%\s*tab title="([^"]+)"\s*%\}(.*?)\{%\s*endtab\s*%\}/m)
      id   = "ht-#{SecureRandom.hex(3)}"

      nav = tabs.each_with_index.map do |(title, _), i|
        active = i.zero? ? " active" : ""
        "<li class=\"nav-item\" role=\"presentation\">" \
          "<button class=\"nav-link#{active}\" data-bs-toggle=\"tab\" " \
          "data-bs-target=\"##{id}-#{i}\" type=\"button\">#{CGI.escapeHTML(title)}</button>" \
        "</li>"
      end.join

      panes = tabs.each_with_index.map do |(_, content), i|
        active = i.zero? ? " show active" : ""
        "<div class=\"tab-pane fade#{active}\" id=\"#{id}-#{i}\" role=\"tabpanel\">#{md_fragment(content.strip)}</div>"
      end.join

      html = "<ul class=\"nav nav-tabs mb-3\" role=\"tablist\">#{nav}</ul>\n<div class=\"tab-content mb-3\">#{panes}</div>"
      placeholder(blocks, html)
    end
  end

  def md_fragment(text)
    md = Redcarpet::Markdown.new(Renderer.new(hard_wrap: false),
           tables: true, fenced_code_blocks: true, strikethrough: true)
    md.render(text)
  end
end
