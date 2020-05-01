class UnpublishingPresenter < ContentItemPresenter
  attr_reader :alternative_url, :explanation

  def initialize(content_item, requested_path = nil)
    super
    @explanation = content_item["details"]["explanation"]
    @alternative_url = content_item["details"]["alternative_url"]
  end

  def page_title
    "No longer available"
  end
end
