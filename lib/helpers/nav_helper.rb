module NavigationHelper
  def active?(item)
    item == @item
  end

  # Returns every navigable item
  # A navigable item contains the :navigable attribute
  # Optionally contains an order attribute, determining the order in the navbar
  def navigables
    items.select { |i| i[:navigation] }.sort_by { |x| x[:order] || 10_000 }
  end
end
