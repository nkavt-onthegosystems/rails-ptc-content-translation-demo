class Post < ApplicationRecord
  extend Mobility
  translates :title, type: :string
  translates :description, type: :text

  after_create :send_for_translation

  def set_translation(locale:, title:, description:)
    send("title_#{locale}=", title)
    send("description_#{locale}=", description)

    save!
  end

  private

  def send_for_translation
    data = Ptc::TranslateService.call(data: { title: title, description: description }, name: title, target_languages: ["fr", "de"])

    CheckTranslationJob.set(wait: 1.minute).perform_later(id: data["id"], post_id: id)
  end
end