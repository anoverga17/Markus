require 'rails_helper'

describe 'logging in', type: :system do
  let(:simulate_login) do
    # Go to root path
    visit root_path
    # Select option to log in using MarkUs
    click_link(I18n.t('main.login_with', name: Settings.local_auth_login_name ||
      I18n.t('main.local_authentication_default_name')), href: nil)
    # Enter username and password
    fill_in('user_login', with: user_name, id: 'user_login')
    fill_in('user_password', with: 'x', id: 'user_password')
    # Login to MarkUs
    click_button(I18n.t('main.log_in'), name: 'commit')
  end

  before do
    driven_by :selenium, using: :headless_chrome, screen_size: [700, 700],
                         options: {
                           browser: :remote,
                           url: 'http://host.docker.internal:9515'
                         }
  end

  context 'Instructor' do
    let(:user_name) { create(:instructor).user_name }
    it 'signs in and redirects to the courses page' do
      simulate_login
      expect(page).to have_current_path(courses_path)
    end
  end
  context 'TA' do
    let(:user_name) { create(:ta).user_name }
    it 'signs in and redirects to the courses page' do
      simulate_login
      expect(page).to have_current_path(courses_path)
    end
  end
  context 'Student' do
    let(:user_name) { create(:student).user_name }
    it 'signs in and redirects to the courses page' do
      simulate_login
      expect(page).to have_current_path(courses_path)
    end
  end
  context 'Admin' do
    let(:user_name) { create(:admin_user).user_name }
    it 'signs in and redirects to the admin page' do
      simulate_login
      expect(page).to have_current_path(admin_path)
    end
  end
  context 'Unknown User' do
    let(:user_name) { 'Unknown User' }
    it 'fails to sign in' do
      simulate_login
      expect(page).to have_content(I18n.t('main.login_failed'))
    end
  end
end
