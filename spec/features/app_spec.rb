require 'spec_helper'
require './app/app.rb'

feature KayochinGohan::App do
  scenario 'httpまたはhttps以外のURLを入力する' do
    visit '/'
    fill_in 'image_url', with: 'javascript://example.com'
    click_button 'image_url_submit'
    expect(page).to have_content('kayochin gohan')
  end

  scenario 'リソースが存在しないURLを入力する' do
    visit '/'
    fill_in 'image_url', with: 'http://app.naidente.org/notfound.jpg'
    click_button 'image_url_submit'
    expect(page).to have_content('指定したURLの画像は存在しません')
  end

  scenario '画像ではないURLを入力する' do
    visit '/'
    fill_in 'image_url', with: 'http://app.naidente.org/'
    click_button 'image_url_submit'
    expect(page.status_code).to eq 200
    expect(page).to have_content('指定したURLは画像ではありません。画像のURLを入力してください')
  end
end
