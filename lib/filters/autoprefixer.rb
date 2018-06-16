require 'v8'
require 'autoprefixer-rails'

Nanoc::Filter.define(:autoprefixer) do |content, _|
  AutoprefixerRails.process(content).css
end
