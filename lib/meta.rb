require 'sinatra'
require 'slim'
class Meta < Sinatra::Base

  enable :inline_templates
  set :protection, reaction: :warn

  def racktables_user
    if session.key?('user')
      return session['user']
    elsif env.key?('racktables.auth')
      return env['racktables.auth']['user']
    end
  end

  get '/' do
    redirect '/_meta/api-key/'
  end

  get %r{/api-key/?} do
    @api_keys = Model::ApiKey.filter(:owner=>racktables_user)
    render :slim, :index
  end

  post '/api-key/new' do
    key = Model::ApiKey.generate(:owner => racktables_user)
    redirect "/_meta/api-key/#api-key-#{key.key}"
  end

  post '/api-key/:key' do
    key = Model::ApiKey.filter( :owner=>racktables_user, :key => params['key'] ).first
    halt 404 unless key
    if params['action'] == 'delete'
      key.delete
    elsif params['action'] == 'save'
      key.description = params['description'].to_s
      key.save
      redirect "/_meta/api-key/#api-key-#{key.key}"
    end
    redirect '/_meta/api-key/'
  end

  get '/style.css' do
    sass :style
  end

end
__END__

@@ layout
doctype html
html
  head
    link type="text/css" href="/_meta/style.css" rel="stylesheet"
  body
    .content
      .head
        h1 rt-api Meta
        span.sub You are '#{session['user']}'
      .body == yield

@@ index
- for key in @api_keys do
  div.api-key
    form method="POST" action="/_meta/api-key/#{key.key}"
      a id="api-key-#{key.key}"
      dl
        dt Key
        dd : pre =key.key
        dt Secret
        dd : pre =key.secret
        dt.description Description
        dd
          textarea name="description" = key.description
      br
      button type="submit" name="action" onclick="return confirm('Really delete this key?')" title="Delete this key" value="delete" delete
      button type="submit" name="action" title="Save this key" value="save" save
form method="POST" action="/_meta/api-key/new"
  button.api-key-new type="submit" New Api Key
br style="clear:both"

@@ style
html
  height: 100%

body
  background: #202020
  font-family: 'Lucida Grande',Verdana,sans-serif 
  font-size: 13px
  margin: 0px
  height: 100%

.content
  width: 600px
  margin: 20px auto
  min-height: 100%

.head
  background: black
  color: #404040
  padding: 20px 20px
  border-radius: 20px 20px 0px 0px
  h1
    margin: 0px
  .sub
    color: #202020

.body
  padding: 20px
  background: white
  height: 100%
  color: #202020

.api-key
  border: 3px solid #e0e0e0
  background: #e0e0e0
  margin-bottom: 5px
  padding: 10px
  a
    float: right
  dl
    padding: 0px
  dt
    color: #606060
    float: left
    font-weight: bold
    width: 100px
    text-align: right
    padding-right: 10px
  textarea
    width: 80%

.api-key-new
  font-size: 1.2em
  display: block
  text-align: center
  padding: 10px
  width: 100%
