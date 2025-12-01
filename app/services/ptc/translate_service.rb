require 'net/http'
require 'uri'

module Ptc
  class TranslateService
    def initialize(data:, name: ,target_languages:, callback_url: nil)
      @data = data
      @name = name
      @target_languages = target_languages
      @token = ENV.fetch("PTC_API_TOKEN")
      @callback_url = callback_url
    end

    def call
      translate
    end

    def self.call(**attributes)
      new(**attributes).call
    end

    private
    attr_reader :data, :name, :target_languages, :token, :callback_url

    def translate
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      JSON.parse(response.body)
    end

    def body
      {
        data:,
        name:,
        target_languages:,
        callback_url:,
      }.to_json
    end

    def request
      return @request if @request.present?

      @request ||= Net::HTTP::Post.new(uri)
      @request.content_type = "application/json"
      @request.body = body
      @request["Authorization"] = "Bearer #{token}"
      @request
    end

    def uri
      @uri ||= URI.parse("https://app.ptc.wpml.org/api/v1/content_translation")
    end
  end
end