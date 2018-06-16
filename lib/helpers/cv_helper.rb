module CVHelper
  def stars(amount, max: 3, filled: '★', open: '☆')
    (filled * amount.to_i) + (open * (max - amount.to_i))
  end

  def stars_tex(amount)
    stars(amount, filled: '\\FiveStar', open: '\\FiveStarOpen')
  end

  def cv_entry(entry, *keys)
    values = keys.map { |k| md2tex(entry[k].to_s).delete "\n" }
    "\\vspace{.5em}\\cventry{#{values.join '}{'}}"
  end

  def latex_proficiencies(profs)
    result = []
    result << '\\begin{minipage}{\\textwidth}' \
           << '\\begin{itemize}[leftmargin=.5in]' \
           << profs.map { |p, v| "\\item[#{stars_tex p}] #{md2tex v}" } \
           << '\\end{itemize}' \
           << '\\end{minipage}'
    result.join "\n"
  end

  def add_to(contacts, key, icon)
    return unless item[key]
    values = item[key]
    values = [values] unless values.instance_of?(Array)
    values.each do |value|
      contact = { value: value, icon: icon }
      contact[:url] = yield value if block_given?
      contacts << contact
    end
  end
end
