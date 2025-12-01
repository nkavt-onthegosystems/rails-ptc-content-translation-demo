class CheckTranslationJob < ApplicationJob

  MAX_ATTEMPTS = 3

  def perform(id:, post_id:, attempt: 0)
    translation = Ptc::GetTranslationStatusService.call(id:)
    if translation["status"] == "completed"
      translation = Ptc::GetTranslationService.call(id:)
      post = Post.find(post_id)
      translation.except("source").each do |locale, data|
        post.set_translation(locale:, title: data["title"], description: data["description"])
      end
    else
      raise "Failed to get translation after #{MAX_ATTEMPTS} attempts" if attempt > MAX_ATTEMPTS

      CheckTranslationJob.set(wait: 1.minute).perform_later(id:, post_id:, attempt: attempt + 1)
    end
  end
end