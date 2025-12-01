class Post < ApplicationRecord
  extend Mobility
  translates :title, type: :string
  translates :description, type: :text
end