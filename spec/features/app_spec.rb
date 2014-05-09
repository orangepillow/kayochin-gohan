require 'spec_helper'
require './app/app.rb'

feature KayochinGohan::App do
  scenario 'httpまたはhttps以外のURLを入力する' do
    visit '/'
    fill_in 'image_url', with: 'javascript://example.com'
    expect(page).to have_content('kayochin gohan')
  end
end
