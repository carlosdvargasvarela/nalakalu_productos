class HelpController < ApplicationController
  include MarkdownHelper
  CHAPTERS = %w[
    README 01-dashboard 02-movimientos 03-stock-por-sala
    04-registrar-salida 05-stock-inicial 06-ajuste
    07-carga-masiva 08-revision-sync 09-alertas 10-configuracion
  ].freeze

  def show
    chapter = params[:chapter]
    head :not_found and return unless CHAPTERS.include?(chapter)

    path = Rails.root.join("docs/inventarios/#{chapter}.md")
    raw  = File.read(path)
    @title   = extract_title(raw)
    @content = render_markdown(raw)
    render layout: false
  end

  private

  def extract_title(text)
    text.match(/^#\s+(.+)/)&.captures&.first&.gsub(/[*_`]/, "") || "Ayuda"
  end
end
