require 'kramdown'

module LayoutHelper
  def md(text)
    Kramdown::Document.new(text).to_html
  end

  def md2tex(text)
    Kramdown::Document.new(text).to_latex
  end
end
