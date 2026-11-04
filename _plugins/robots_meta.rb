Jekyll::Hooks.register :documents, :post_render do |doc|
  next unless doc.data['robots']
  tag = %(<meta name="robots" content="#{doc.data['robots']}">)
  doc.output = doc.output.sub('</head>', "#{tag}\n</head>")
end

Jekyll::Hooks.register :pages, :post_render do |page|
  next unless page.data['robots']
  tag = %(<meta name="robots" content="#{page.data['robots']}">)
  page.output = page.output.sub('</head>', "#{tag}\n</head>")
end
