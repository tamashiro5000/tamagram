require 'sinatra'
require 'sinatra/reloader'
require 'mysql2'
require "mysql2-cs-bind"
require 'rack/flash'

set :public_folder, 'public'

configure do
  use Rack::Flash
end

enable :sessions

### Mysqlドライバの設定 ###
def db
  @db ||= Mysql2::Client.new(
    host:     ENV['DB_HOST'] || 'localhost',
    port:     ENV['DB_PORT'] || '3306',
    username: ENV['DB_USERNAME'] || 'root',
    password: ENV['DB_PASSWORD'] || '',
    database: ENV['DB_DATABASE'] || 'sinatra_graduation',
  )
end


helpers do
  def login?
    !session[:user_id].nil?
  end
  def current_user
    return nil unless login?
    db.xquery("SELECT id, user_name FROM users where id = ?;", session[:user_id]).first
  end
end


get '/' do
  if login?
    redirect '/form'
  else
    redirect '/login'
  end
end




### ログイン・ログアウトフォーム ###

get '/login' do
  return redirect '/' if login?
  @login_miss = flash[:login_miss]
  @logout = flash[:logout]
  @signup = flash[:signup]

  erb :login_form
end


post '/login' do
  return redirect '/form' if login?

  res = db.xquery("SELECT id FROM users where user_name = ? and user_pass = ?;", params[:login_name], params[:login_pass]).first

    if res
      session[:user_id] = res['id']
      flash[:login] = "#{current_user['user_name'].upcase}さんでログインしました"
      redirect '/form'
    else
      flash[:login_miss] = 'ログイン失敗しました'
    end

  redirect '/login'
end


get '/logout' do
  flash[:logout] = 'ログアウトしました'
  session[:user_id] = nil

  redirect '/'
end


### 投稿フォーム・トップビュー ###

get "/form" do
  @name = current_user['user_name']
  @login = flash[:login]

  sql = "SELECT * FROM posts"
  @posts = db.query(sql).to_a

  icon = "SELECT * FROM icons WHERE id = #{current_user['id']}"
  @icons = db.query(icon).first


  @posts.each_with_index do |post,i|
  result = db.xquery("SELECT COUNT(*) as count FROM likes WHERE post_id = ?", post['id'])
  count = result.first['count']
  @posts[i]['like_count'] = count
  end
  erb :form
end




post "/form" do
  title = params[:title]
  filename = params[:file][:filename]
  file = params[:file][:tempfile]
   File.open("./public/image/#{filename}", 'wb') do |f|
    f.write(file.read)
  end
   sql = "INSERT INTO `posts` (`creater_id`,`title`, `img_path`, `date_info`) VALUES ('#{current_user['id']}','#{title}', '#{filename}', NOW());"
  db.query(sql)
   @posts = db.query("SELECT * FROM posts").to_a
   redirect '/form'
end




#### 削除ルーティング  ###

post '/posts/:id/delete' do |id|
  sql = "DELETE FROM posts WHERE id = ? and creater_id = ?"
  db.xquery(sql, id, current_user['id'])
  redirect '/form'
end



#### 編集ルーティング  ###

get '/posts/:id/edit' do |id|

  sql = "SELECT * FROM posts WHERE id = #{id}"
  @posts = db.xquery(sql).to_a
  icon = "SELECT * FROM icons WHERE id = #{current_user['id']}"
  @icons = db.query(icon).first

  like = "SELECT id FROM posts limit 1;"
  @likes = db.query("SELECT COUNT(*) as count FROM likes WHERE post_id = 1").first['count']

  comment = "SELECT * FROM comments WHERE post_id = 1"
  @comments = db.query(comment).to_a


  erb :edit
end


post '/posts/:id/edit' do |id|
  title = params[:title]
  filename = params[:file][:filename]
  file = params[:file][:tempfile]
   File.open("./public/image/#{filename}", 'wb') do |f|
    f.write(file.read)
  end

   sql = "UPDATE posts SET `title` = '#{title}' WHERE `id` = #{id};"
   sql2 = "UPDATE posts SET `img_path` = '#{filename}' WHERE `id` = #{id};"

   db.xquery(sql)
   @posts = db.xquery("SELECT * FROM posts").to_a
   db.xquery(sql2)
   @posts2 = db.xquery("SELECT * FROM posts").to_a

   redirect '/form'
end




### イイネ！ルーティング  ###

post '/posts/:id/like' do |id|
  sql = "INSERT INTO `likes` (`user_id`, `post_id`) VALUES ('#{current_user['id']}', '#{id}');"
  db.query(sql)
  redirect '/form'
end




### コメント ルーティング  ###

post '/posts/:id/comments' do |id|
  comment = params[:comment]

  sql ="INSERT INTO `comments` (`user_id`, `user_name`, `post_id`, `comment`) VALUES ('#{current_user['id']}','#{current_user['user_name']}', '#{id}', '#{comment}');"
  db.query(sql)
  redirect '/form'
end











### サインアップフォーム ###

get '/signup' do
  return redirect '/' if login?

  @page_info = flash[:page_info]
  erb :signup_form
end


post '/signup' do
  return redirect '/' if login?

  signup_name = params[:signup_name]
  signup_pass = params[:signup_pass]

  filename = params[:file][:filename]
  file = params[:file][:tempfile]
   File.open("./public/icon/#{filename}", 'wb') do |f|
    f.write(file.read)
  end

  res = db.xquery("SELECT * FROM users where user_name = ?;", params[:signup_name]).first

  if res
    flash[:page_info] = "既に存在するユーザーです"
    redirect '/signup'
  else
    sql = "INSERT INTO `users` (`user_name`, `user_pass`) VALUES ('#{signup_name}', '#{signup_pass}');"
    db.xquery(sql)
    sql2 = "INSERT INTO `icons` (`icon_path`) VALUES ('#{filename}');"
    db.xquery(sql2)
    sql3 = "SELECT id FROM users ORDER BY id DESC LIMIT 1;"
    last_users = db.xquery(sql3)
    sql4 = "SELECT id FROM icons ORDER BY id DESC LIMIT 1;"
    last_icons = db.xquery(sql4)
    sql5 = "UPDATE icons SET `creater_id` = 'sql3' WHERE `id` = 'sql4';"
    db.xquery(sql5)
    flash[:signup] = "アカウント作成しました。"
  end

  redirect '/'
end
