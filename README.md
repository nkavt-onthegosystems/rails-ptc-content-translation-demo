# How to translate model content in Rails with PTC

Here we'll explain how to create a Rails application with a translatable `Post` model using Mobility, then how to connect it to the PTC Content Translations API and retrieve translations.

Note: You should have basic knowledge of Ruby and Ruby on Rails to follow the examples.


## Set up a Rails application

To set up a new Rails app, run:
```bash
rails new blog
```

This will create a Rails application for us.

## Add Mobility

### Install Mobility
To add the Mobility gem into our Rails application, add it to the Gemfile:

```
# ..Other gemfile content
gem 'mobility'
#...
``` 

Then run
```bash
bundle install
```

### Configure Mobility
We need to run this command:
```bash
rails generate mobility:install
```

It will create `config/initializers/mobility.rb`.

## Scaffold Post model

### 1. Generate Post scaffold with basic attributes (no translations yet)

```bash
rails generate scaffold Post published:boolean
```


### 2. Run the migration

```bash
rails db:migrate
```


### 3. Update Post model to use Mobility translations

Edit `app/models/post.rb`:

```ruby
class Post < ApplicationRecord
  extend Mobility
  translates :title, type: :string
  translates :description, type: :text
end

```


### 4. Adjust PostsController strong params to permit translated attributes

Edit `app/controllers/posts_controller.rb`:

```ruby
def post_params
  params.require(:post).permit(:published, :title, :description)
end
```

### 5. Modify views to support editing translations (for current locale)

Edit `app/views/posts/_form.html.erb`:

```erb
<div class="field">
  <%= form.label :title %>
  <%= form.text_field :title %>
</div>

<div class="field">
  <%= form.label :description %>
  <%= form.text_area :description %>
</div>

<div class="field">
  <%= form.label :published %>
  <%= form.check_box :published %>
</div>
```

### 6. Add available languages

To add available languages, in `config/application.rb` add the following:
```ruby
config.i18n.available_locales = [:en, :fr, :de]
config.i18n.default_locale = :en
```

### 7. Test it out

Run the server:

```bash
rails server
```

In Rails console, try:
```
rails c
```
```ruby
I18n.locale = :en
post = Post.create(title: "Hello", description: "Welcome to the blog", published: true)

I18n.locale = :fr
post.title = "Bonjour"
post.description = "Bienvenue sur le blog"
post.save
```

## Translating with PTC

### Adding API token
First, generate a token in PTC: Settings → Manage API Tokens → Add access token.

After generating the token, create a `.env` file:

```
PTC_API_TOKEN={your_api_token}
```

### Install dotenv-rails gem

To access environment variables, install the `dotenv-rails` gem. Add this to the Gemfile:

```
gem 'dotenv-rails', groups: [:development, :test]
```

and run:

```bash
bundle install
```

### Sending translation strings to PTC for translation


#### Create a service that calls the PTC API `app/services/ptc/translate_service.rb`

```ruby
require 'net/http'
require 'uri'

module Ptc
  class TranslateService
    def initialize(data:, name: ,target_languages: )
      @data = data
      @name = name
      @target_languages = target_languages
      @token = ENV.fetch("PTC_API_TOKEN")
    end

    def call
      translate
    end

    def self.call(**attributes)
      new(**attributes).call
    end

    private
    attr_reader :data, :name, :target_languages, :token

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
```

Set up a hook on `Post` so when it's created it calls the API:

Add following to the 'app/models/post.rb'
```ruby
class Post < ApplicationRecord
  # ...
  after_create :send_for_translation
  # ...
  private
  # ...
  def send_for_translation
    Ptc::TranslateService.call(data: { title: title, description: description }, name: title, target_languages: ["fr", "de"])
  end
  # ... 
end
```

This calls the translation service when a post is created.

### Retrieving translations from PTC

There are two ways to retrieve translations from PTC: (1) poll the API for status and results, or (2) set up a webhook and provide a callback URL. Using a callback is preferred over polling because it avoids repeatedly checking until the translation is ready.

Before we start, add `locale_accessors` for Mobility in `config/initializers/mobility.rb`:

```ruby
plugins do
  # Other code..
  locale_accessors [:en, :fr, :de]
end
```

Then add set_translation function on Posts model

`app/models/post.rb`
```ruby
class Post < ApplicationRecord
  # ..
  def set_translation(locale:, title:, description:)
    send("#{locale}=", title)
    send("#{locale}_description=", description)
  end

  # ..
end
```

#### Retrieving translations by polling

First, create a service that accepts the id received from the API and checks the translation status:

`app/services/ptc/get_translation_status_service.rb`
```ruby
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
```

Then we'll add service which will get translations for id received from service

`app/services/ptc/get_translation_service.rb`

```ruby
require 'net/http'
require 'uri'

module Ptc
  class GetTranslationService
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
      @uri ||= URI.parse("https://app.ptc.wpml.org/api/v1/content_translation/#{id}")
    end
  end
end
```

Next, create a job that checks the status; if it's completed it updates translations on the post, otherwise it re-enqueues itself with a delay. Limit the number of attempts to avoid an infinite loop.


`app/jobs/check_translation_job.rb`
```ruby
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

```


To run the job, we need to install `delayed_job_active_record`. 

1. Add `delayed_job_active_record` in the `Gemfile`
```
gem 'delayed_job_active_record'
```

2. Run:
```bash
bundle install
```

3. Generate ActiveRecord tables for Delayed Job
```
rails generate delayed_job:active_record
```

4. Migrate the database
```bash
rails db:migrate
```

5. Add adapter to `config/application.rb`

```
config.active_job.queue_adapter = :delayed_job
```

After this, enqueue the worker when triggering translations by updating the hook
`app/models/post.rb`
```ruby
class Post < ApplicationRecord
 
  # Other code.,..
  def send_for_translation
    data = Ptc::TranslateService.call(data: { title: title, description: description }, name: title, target_languages: ["fr", "de"],)

    CheckTranslationJob.set(wait: 1.minute).perform_later(id: data["id"], post_id: id)
  end
end
```

This will poll the services. We need to restart our Rails server and start the job workers. 


#### Retrieve translations via callback

As mentioned, the best way to retrieve translations is by providing a callback URL. In development mode, PTC won't be able to access your local server, so we need to expose it. In this example, we'll use [ngrok](https://ngrok.com/docs/getting-started).

Expose the localhost by running:
```bash
ngrok http 3000
```

It will return a URL. If you try to access this URL, Rails will raise an error because we need to add it to the allowed hosts.
Add the ngrok URL to the `.env` file first (replace `aaaaaaaa.ngrok-free.app` with your ngrok URL):
```
HOST=aaaaaaaa.ngrok-free.app 
```

Then add that URL into our configuration.

`config/application.rb`
```ruby
config.hosts << ENV.fetch("HOST")
```
In the same file, add default host and protocol at the end:
```ruby
Rails.application.routes.default_url_options = {
  host: ENV.fetch("HOST"),
  protocol: ENV.fetch("PROTOCOL", "https")
}
```

After this, restart the server and the Rails app should be accessible via the ngrok URL.

Now we need to set up a callback URL for our translations in the API.

`app/controllers/api/callbacks_controller.rb`
```ruby
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
```

And add it to routes
```ruby
Rails.application.routes.draw do
  resources :posts
  namespace :api, defaults: { format: :json } do
    post "posts/:post_id/callback", to: "callbacks#create", as: :post_callback
  end
end

```

Then update our translation service to include callback_url
```ruby
require 'net/http'
require 'uri'

module Ptc
  class TranslateService
    def initialize(data:, name: ,target_languages:, callback_url:nil)
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
```

Now we'll update the hook to include the callback URL

```ruby
class Post < ApplicationRecord
  # Other code...
  def send_for_translation
    Ptc::TranslateService.call(
      data: { title: title, description: description },
      name: title,
      target_languages: ["fr", "de"],
      callback_url: Rails.application.routes.url_helpers.api_post_callback_url(post_id: id)
    )
  end
end
```

### Showing translations

Since we should now have translations, let's show them on the scaffolded UI. To do so, update:
`app/views/posts/_post.html.erb`
```erb
<div id="<%= dom_id post %>">
  <% [:en, :fr, :de].each do |locale| %>
    <p>
      <strong>Title (<%= locale.to_s.upcase %>):</strong>
      <%= post.send("title_#{locale}") %>
    </p>
  <% end %>
  <% [:en, :fr, :de].each do |locale| %>
    <p>
      <strong>Description (<%= locale.to_s.upcase %>):</strong>
      <%= post.send("description_#{locale}") %>
    </p>
  <% end %>
  <p>
    <strong>Published:</strong>
    <%= post.published %>
  </p>

</div>
```

Now you can add post and it'll be automatically translated by PTC.