require 'sinatra'
require 'sinatra/reloader'
require 'json'
require 'mysql2'

set :public_folder, 'public'

enable :sessions

### Mysqlドライバの設定 ###
def db
  @db ||= Mysql2::Client.new(
    host:     ENV['DB_HOST'] || 'localhost',
    port:     ENV['DB_PORT'] || '3306',
    username: ENV['DB_USERNAME'] || 'root',
    password: ENV['DB_PASSWORD'] || '',
    database: ENV['DB_DATABASE'] || 'mydb',
  )
end

get '/' do
  if @name
    erb :form
  end

  sql = "SELECT * FROM posts"
  result = db.query(sql).to_a

  erb :index
end



### サインアップフォーム ###

json_user = File.dirname(__FILE__) + '/data/user.json'

get '/sign_up' do
  erb :sign_up_form
end


post '/sign_up' do

  datum = {
    "name" => params[:name],
    "password" => params[:password],
    }

  data = []
  open(json_user) do |io|
    data = JSON.load(io)
  end

  data << datum

  open(json_user, 'w') do |io|
    JSON.dump(data, io)
  end

  redirect '/'
end




### ログイン・ログアウトフォーム ###

get '/login' do
  erb :login_form
end


post '/login' do
    if params[:name] == 'tamashiro' && params[:password] == 'tamashiro'
      session[:login] = 'タマシロ'
      session[:message] = 'ログインしました'
      redirect '/form'
    else
      session[:message] = 'ログイン失敗しました'
    end
  redirect '/login'
end

get '/logout' do
  session[:login] = nil
  redirect '/'
end


### 投稿フォーム ###

get "/form" do
  @name = session[:login]
  @message = session[:message]
  session[:message] = nil

  sql = "SELECT * FROM posts"
  @posts = db.query(sql).to_a
   erb :form
end


post "/form" do
  title = params[:title]
  filename = params[:file][:filename]
  file = params[:file][:tempfile]
   File.open("./public/image/#{filename}", 'wb') do |f|
    f.write(file.read)
  end
   sql = "INSERT INTO `posts` (`title`, `image`, `created_at`) VALUES ('#{title}', '#{filename}', NOW());"
  db.query(sql)
   @posts = db.query("SELECT * FROM posts").to_a
   redirect '/form'
end
