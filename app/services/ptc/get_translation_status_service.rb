require 'net/http'
require 'uri'

module Ptc
  class GetTranslationStatusService
    def initialize(id:)
      @id = id
      @token = ENV.fetch("PTC_API_TOKEN")
    end

    def call
      get
    end

    def self.call(**attributes)
      new(**attributes).call
    end

    private
    attr_reader :id, :token

    def get
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      JSON.parse(response.body)
    end

    def request
      return @request if @request.present?

      @request ||= Net::HTTP::Get.new(uri)
      @request.content_type = "application/json"
      @request["Authorization"] = "Bearer #{token}"
      @request
    end

    def uri
      @uri ||= URI.parse("https://app.ptc.wpml.org/api/v1/content_translation/#{id}/status")
    end
  end
end