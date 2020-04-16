module ContentItem
  module NewsImage
    def image
      content_item.dig("details", "image") || default_news_image || placeholder_image
    end

  private

    def default_news_image
      organisation = content_item.dig("links", "primary_publishing_organisation")
      organisation[0].dig("details", "default_news_image") if organisation.present?
    end

    def placeholder_image
      # this image has been uploaded to asset-manager
      { "url" => "https://assets.publishing.service.gov.uk/media/5e985599d3bf7f3fc943bbd8/UK_government_logo.jpg" }
    end
  end
end
