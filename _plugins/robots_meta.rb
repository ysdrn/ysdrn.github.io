Jekyll::Hooks.register :site, :post_render do |site|
  all = site.docs_to_write + site.pages
  all.each do |item|
    next unless item.data['robots'] && item.output
    tag = %(<meta name="robots" content="#{item.data['robots']}">)
    item.output = item.output.sub('</head>', "#{tag}\n</head>")
  end
end
