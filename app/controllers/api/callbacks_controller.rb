module Api
  class CallbacksController < ActionController::API
    before_action :set_post

    def create
      id = callback_params[:id]

      translation_data = Ptc::GetTranslationService.call(id:)
      translation_data.except("source").each do |locale, data|
        @post.set_translation(locale:, title: data["title"], description: data["description"])
      end

      head :ok
    end

    private

    def set_post
      @post = Post.find(params[:post_id])
    end

    def callback_params
      params.permit([:post_id, :id, :status, :translations_url])
    end
  end
end