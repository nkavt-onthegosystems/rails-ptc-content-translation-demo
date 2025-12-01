class Post < ApplicationRecord
  extend Mobility
  translates :title, type: :string
  translates :description, type: :text

  after_create :send_for_translation

  private

  def send_for_translation
    Ptc::TranslateService.call(data: { title: title, description: description }, name: title, target_languages: ["fr", "de"])
  end
end