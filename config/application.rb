require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Blog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    config.active_job.queue_adapter = :delayed_job

    config.i18n.available_locales = [:en, :fr, :de]
    config.i18n.default_locale = :en

    config.hosts << ENV.fetch("HOST")

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end

Rails.application.routes.default_url_options = {
  host: ENV.fetch("HOST"),
  protocol: ENV.fetch("PROTOCOL", "https")
}