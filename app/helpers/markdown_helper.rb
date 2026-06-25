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
    html = preprocess(text)
    md   = Redcarpet::Markdown.new(Renderer.new(hard_wrap: false),
             tables: true, fenced_code_blocks: true,
             autolink: true, strikethrough: true, no_intra_emphasis: true)
    md.render(html).html_safe
  end

  private

  def preprocess(text)
    text = convert_mermaid(text)
    text = convert_hints(text)
    text = convert_tabs(text)
    text
  end

  def convert_mermaid(text)
    # Raw div — no code-block wrapper so mermaid.js can parse the text content directly.
    text.gsub(/```mermaid\n(.*?)```/m) do
      "\n<div class=\"help-mermaid\">#{$1.strip}</div>\n"
    end
  end

  def convert_hints(text)
    text.gsub(/\{%\s*hint style="(\w+)"\s*%\}(.*?)\{%\s*endhint\s*%\}/m) do
      style   = $1
      color   = HINT_COLORS[style] || "secondary"
      icon    = HINT_ICONS[style]  || "bi-info-circle-fill"
      content = md_fragment($2.strip)
      <<~HTML
        <div class="help-hint help-hint--#{style} alert alert-#{color} d-flex gap-2 align-items-start">
          <i class="bi #{icon} flex-shrink-0 mt-1"></i>
          <div class="help-hint__body">#{content}</div>
        </div>
      HTML
    end
  end

  def convert_tabs(text)
    text.gsub(/\{%\s*tabs\s*%\}(.*?)\{%\s*endtabs\s*%\}/m) do
      raw_tabs = $1
      tabs     = raw_tabs.scan(/\{%\s*tab title="([^"]+)"\s*%\}(.*?)\{%\s*endtab\s*%\}/m)
      id       = "ht-#{SecureRandom.hex(3)}"

      nav = tabs.each_with_index.map do |(title, _), i|
        active = i.zero? ? " active" : ""
        "<li class=\"nav-item\" role=\"presentation\">" \
          "<button class=\"nav-link#{active}\" data-bs-toggle=\"tab\" " \
          "data-bs-target=\"##{id}-#{i}\" type=\"button\">#{CGI.escapeHTML(title)}</button>" \
        "</li>"
      end.join

      panes = tabs.each_with_index.map do |(_, content), i|
        active  = i.zero? ? " show active" : ""
        # hints inside tab content are already HTML; run md on remaining markdown
        rendered = md_fragment(content.strip)
        "<div class=\"tab-pane fade#{active}\" id=\"#{id}-#{i}\" role=\"tabpanel\">#{rendered}</div>"
      end.join

      <<~HTML
        <ul class="nav nav-tabs mb-3" role="tablist">#{nav}</ul>
        <div class="tab-content mb-3">#{panes}</div>
      HTML
    end
  end

  def md_fragment(text)
    md = Redcarpet::Markdown.new(Renderer.new(hard_wrap: false),
           tables: true, fenced_code_blocks: true, strikethrough: true)
    md.render(text)
  end
end
