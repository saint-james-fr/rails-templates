
run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# Gemfile
########################################
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "devise"
    gem "autoprefixer-rails"
    gem "font-awesome-sass", "~> 6.1"
    gem "simple_form", github: "heartcombo/simple_form"
  RUBY
end

inject_into_file "Gemfile", after: 'gem "debug", platforms: %i[ mri mingw x64_mingw ]' do
<<-RUBY

  gem "dotenv-rails"
RUBY
end

gsub_file("Gemfile", '# gem "sassc-rails"', 'gem "sassc-rails"')

# Assets
########################################
run "rm -rf app/assets/stylesheets"
run "rm -rf vendor"
run "curl -L https://github.com/lewagon/rails-stylesheets/archive/master.zip > stylesheets.zip"
run "unzip stylesheets.zip -d app/assets && rm -f stylesheets.zip && rm -f app/assets/rails-stylesheets-master/README.md"
run "mv app/assets/rails-stylesheets-master app/assets/stylesheets"

inject_into_file "config/initializers/assets.rb", before: "# Precompile additional assets." do
  <<~RUBY
    Rails.application.config.assets.paths << Rails.root.join("node_modules")
  RUBY
end

# Layout
########################################

gsub_file(
  "app/views/layouts/application.html.erb",
  '<meta name="viewport" content="width=device-width,initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">'
)

# Flashes
########################################
file "app/views/shared/_flashes.html.erb", <<~HTML
  <% if notice %>
    <div class="alert alert-info alert-dismissible fade show m-1" role="alert">
      <%= notice %>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close">
      </button>
    </div>
  <% end %>
  <% if alert %>
    <div class="alert alert-warning alert-dismissible fade show m-1" role="alert">
      <%= alert %>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close">
      </button>
    </div>
  <% end %>
HTML

inject_into_file "app/views/layouts/application.html.erb", after: "<body>" do
  <<~HTML
    <%= render "shared/flashes" %>
  HTML
end

# README
########################################
markdown_file_content = <<~MARKDOWN
  Rails app generated with [lewagon/rails-templates](https://github.com/lewagon/rails-templates), created by the [Le Wagon coding bootcamp](https://www.lewagon.com) team.
MARKDOWN
file "README.md", markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

environment generators

########################################
# After bundle
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command "db:drop db:create db:migrate"
  # generate("simple_form:install", "--bootstrap")
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")

  # Routes
  ########################################
  route 'root to: "pages#home"'

  # Gitignore
  ########################################
  append_file ".gitignore", <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Devise install + user
  ########################################
  generate("devise:install")
  generate("devise", "User")

  # Application controller
  ########################################
  run "rm app/controllers/application_controller.rb"
  file "app/controllers/application_controller.rb", <<~RUBY
    class ApplicationController < ActionController::Base
      before_action :authenticate_user!
    end
  RUBY

  # migrate + devise views
  ########################################
  rails_command "db:migrate"
  generate("devise:views")

  gsub_file(
    "app/views/devise/registrations/new.html.erb",
    "<%= simple_form_for(resource, as: resource_name, url: registration_path(resource_name)) do |f| %>",
    "<%= simple_form_for(resource, as: resource_name, url: registration_path(resource_name), data: { turbo: :false }) do |f| %>"
  )
  gsub_file(
    "app/views/devise/sessions/new.html.erb",
    "<%= simple_form_for(resource, as: resource_name, url: session_path(resource_name)) do |f| %>",
    "<%= simple_form_for(resource, as: resource_name, url: session_path(resource_name), data: { turbo: :false }) do |f| %>"
  )
  link_to = <<~HTML
    <p>Unhappy? <%= link_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete %></p>
  HTML
  button_to = <<~HTML
    <div class="d-flex align-items-center">
      <div>Unhappy?</div>
      <%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete, class: "btn btn-link" %>
    </div>
  HTML
  gsub_file("app/views/devise/registrations/edit.html.erb", link_to, button_to)

  # Pages Controller
  ########################################
  run "rm app/controllers/pages_controller.rb"
  file "app/controllers/pages_controller.rb", <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: "development"
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: "production"

  # Yarn
  ########################################
  # run "yarn add bootstrap @popperjs/core"
  # append_file "app/javascript/application.js", <<~JS
  #  import "bootstrap"
  # JS

  # Heroku
  ########################################
  run "bundle lock --add-platform x86_64-linux"

  # Dotenv
  ########################################
  run "touch '.env'"

  # Rubocop
  ########################################
  run "curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml"

  # Git
  ########################################
  git :init
  git add: "."
  git commit: "-m 'Initial commit with devise'"

  #Adding Vite
  ########################################


  # Add Vite to Gemfile
  inject_into_file "Gemfile", before: 'gem "jsbundling-rails' do
    <<~RUBY
      gem "vite_rails"
      gem "vite_ruby"
    RUBY
  end

  # Remove ESBuild with yarn
  run "yarn remove esbuild"

  # Remove Build script from package json
  gsub_file("package.json", '"build": "esbuild app/javascript/*.* --bundle --sourcemap --outdir=app/assets/builds --public-path=assets"', '')
  # Remove JsBundlingRails Gem
  gsub_file('Gemfile', 'gem "jsbundling-rails"', '')
  gsub_file('Gemfile', '# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]', '')

  # run bundler
  run 'bundle'
  # run vite install
  run 'bundle exec vite install'

  # Add Tailwind and other dependencies/plugins
  run 'yarn add tailwindcss @tailwindcss/forms @tailwindcss/typography @tailwindcss/aspect-ratio @tailwindcss/forms @tailwindcss/line-clamp autoprefixer'
  run 'yarn add -D eslint prettier eslint-plugin-prettier eslint-config-prettier eslint-plugin-tailwindcss path vite-plugin-full-reload vite-plugin-stimulus-hmr'

  # edit Vite config file
  file = 'vite.config.ts'
  File.open(file, 'w') do |f|
    f.write 'import {defineConfig} from "vite"
import FullReload from "vite-plugin-full-reload"
import RubyPlugin from "vite-plugin-ruby"
import StimulusHMR from "vite-plugin-stimulus-hmr"

export default defineConfig({
      clearScreen: false,
      plugins: [
          RubyPlugin(),
          StimulusHMR(),
          FullReload(["config/routes.rb", "app/views/**/*"], {delay: 300}),
      ],

    }
)
'
  end

  # Tailwind Initialization
  run 'tailwind init'

  # Modification of Tailwind Config file
  file = 'tailwind.config.js'
  File.open(file, 'w') do |f|
    f.write '/** @type {import("tailwindcss").Config} */
const colors = require("tailwindcss/colors")
const defaultTheme = require("tailwindcss/defaultTheme")

module.exports = {
  content: [
    "./app/helpers/**/*.rb",
    "./app/assets/stylesheets/**/*.css",
    "./app/views/**/*.{html,html.erb,erb}",
    "./app/javascript/components/**/*.js",
  ],
  theme: {
    fontFamily: {
      "sans": ["BlinkMacSystemFont", "Avenir Next", "Avenir",
        "Nimbus Sans L", "Roboto", "Noto Sans", "Segoe UI", "Arial", "Helvetica",
        "Helvetica Neue", "sans-serif"],
      "mono": ["Consolas", "Menlo", "Monaco", "Andale Mono", "Ubuntu Mono", "monospace"]
    },
    extend: {
    },
  },
  corePlugins: {
    aspectRatio: false,
  },
  plugins: [
    require("@tailwindcss/typography"),
    require("@tailwindcss/forms"),
    require("@tailwindcss/aspect-ratio"),
    require("@tailwindcss/line-clamp"),
  ],
}
'
  end

  # Add SimpleForm Config to Tailwind to Gemfile
  inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      gem "simple_form-tailwind"

    RUBY
  end

  # run bundler
  run 'bundle'

   # Add Tailwind to application.css
  file = 'app/assets/stylesheets/application.css'
  File.open(file, 'w') do |f|
    f.write '@import "tailwindcss/base";

@import "tailwindcss/components";

@import "tailwindcss/utilities";
    '
  end

  # Create a file named application.css in app/javascript/entrypoints and add the following line:
  string = 'echo "@import \"../../assets/stylesheets/application.css\";" > app/javascript/entrypoints/application.css'
  run string

  # create a file names postcss.config.js and add the following lines:
  run 'touch postcss.config.js'
  file = 'postcss.config.js'
  File.open(file, 'w') do |f|
    f.write 'module.exports = {
      plugins: {
        tailwindcss: {},
        autoprefixer: {},
      },
    }
    '
  end

# Change Tags in application.html.erb
  file = 'app/views/layouts/application.html.erb'
  File.open(file, 'w') do |f|
    f.write '<!DOCTYPE html>
<html>
  <head>
    <title>Vitevitevite</title>
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= vite_client_tag %>
    <%= vite_stylesheet_tag "application", data: { "turbo-track": "reload" } %>
    <%= vite_javascript_tag "application" %>

  </head>

  <body>
    <%= render "shared/flashes" %>
    <%= yield %>
  </body>
</html>
    '
  end

# Change Procfile.dev configuration
  file = 'Procfile.dev'
  File.open(file, 'w') do |f|
    f.write 'web: bin/rails server -p 3000
vite: bin/vite dev --clobber'
  end

# Change HOME page
run 'rm app/views/pages/home.html.erb'
file "app/views/pages/home.html.erb", <<~HTML
<div class="relative flex min-h-screen flex-col justify-center overflow-hidden bg-gray-50 py-6 sm:py-12">
  <div class="relative mx-32 bg-white px-6 pt-10 pb-8 shadow-xl sm:rounded-lg sm:px-10">
    <div class="mx-auto">
      <img src="https://vite-ruby.netlify.app/logo.svg" class="h-32" />
      <h1 class="mt-6 mb-12 text-center font-sans text-5xl">Vite Rails</h1>
      <section class="justify-center-center my-0 mx-auto flex flex-wrap justify-between px-8 pt-0 pb-16 leading-6 tracking-normal">
        <a class="max-h-32 max-w-[23rem] flex-shrink flex-grow-0 cursor-pointer rounded-lg bg-gray-200 py-6 px-8 text-sm font-medium leading-6 tracking-normal shadow-xl" href="/">
          <h2 class="mx-0 mt-0 mb-3 cursor-pointer text-xl font-semibold leading-6 tracking-tight">🔥 Fast Server Start</h2>
          <p class="m-0 cursor-pointer text-sm font-medium leading-6 tracking-normal">Unlike Webpacker, files are processed on demand!</p>
        </a>

        <a class="my-6 max-h-32 max-w-[23rem] flex-shrink flex-grow-0 cursor-pointer rounded-lg bg-gray-100 bg-transparent py-6 px-8 text-sm font-medium leading-6 tracking-normal shadow-xl" href="/">
          <h2 class="mx-0 mt-0 mb-3 cursor-pointer text-xl font-semibold leading-6 tracking-tight">⚡️ Instant Changes</h2>
          <p class="m-0 cursor-pointer text-sm font-medium leading-6 tracking-normal">Fast updates thanks to HMR. Goodbye full-page reloads!</p>
        </a>

        <a class="max-h-32 max-w-[23rem] flex-shrink flex-grow-0 cursor-pointer rounded-lg bg-gray-200 bg-transparent py-6 px-8 text-sm font-medium leading-6 tracking-normal shadow-xl" href="/">
          <h2 class="mx-0 mt-0 mb-3 cursor-pointer text-xl font-semibold leading-6 tracking-tight">🚀 Zero-Config Deploys</h2>
          <p class="m-0 cursor-pointer text-sm font-medium leading-6 tracking-normal">Integrates with Rake asset management tasks.</p>
        </a>
      </section>
    </div>
  </div>
</div>
HTML

end
