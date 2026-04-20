require "base64"
require "net/http"
require "uri"
require "json"

class MicrosoftGraphMailer
  GRAPH_API_URL = "https://graph.microsoft.com/v1.0/me/sendMail"

  def initialize(user)
    @user = user
    @access_token = user.active_microsoft_token
  end

  def send_purchase_order(purchase_order, recipient_email, extra_attachments: [], note: nil)
    raise "Usuario sin token de Microsoft activo" unless @access_token
    raise "Destinatario no puede estar vacío" unless recipient_email.present?

    pdf_content = purchase_order.as_pdf
    raise "No se pudo generar el PDF" if pdf_content.nil?

    uri = URI.parse(GRAPH_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Authorization"] = "Bearer #{@access_token}"
    request["Content-Type"] = "application/json"
    request.body = build_payload(purchase_order, recipient_email, pdf_content, extra_attachments, note).to_json

    response = http.request(request)
    Rails.logger.info "Graph API Response: #{response.code} - #{response.body}"

    case response.code.to_i
    when 202 then true
    when 401 then raise "Token de Microsoft inválido o expirado. Reconecta tu cuenta de Outlook."
    when 403 then raise "Sin permisos para enviar correos. Verifica los scopes de la app en Azure."
    else
      raise "Error de Microsoft Graph (#{response.code}): #{response.body}"
    end
  end

  private

  def build_payload(purchase_order, recipient_email, pdf_content, extra_attachments, note)
    body_content = "Buen día,<br><br>"
    body_content += "Adjuntamos la orden de compra No. <b>#{purchase_order.id}</b> en formato PDF."
    body_content += "<br><br><i>#{note}</i>" if note.present?
    body_content += "<br><br>Saludos,<br><b>Equipo Nalakalú</b>"

    attachments = [
      {
        "@odata.type": "#microsoft.graph.fileAttachment",
        name: "Orden_Compra_#{purchase_order.id}.pdf",
        contentType: "application/pdf",
        contentBytes: Base64.strict_encode64(pdf_content)
      }
    ]

    Array(extra_attachments).each do |file|
      next if file.blank?
      attachments << {
        "@odata.type": "#microsoft.graph.fileAttachment",
        name: file.original_filename,
        contentType: file.content_type,
        contentBytes: Base64.strict_encode64(file.read)
      }
    end

    {
      message: {
        subject: "Orden de Compra Nalakalú - ##{purchase_order.id}",
        body: {contentType: "HTML", content: body_content},
        toRecipients: [{emailAddress: {address: recipient_email}}],
        attachments: attachments
      },
      saveToSentItems: "true"
    }
  end
end
