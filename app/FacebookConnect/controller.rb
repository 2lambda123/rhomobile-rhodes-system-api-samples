require 'rho/rhocontroller'

class FacebookConnectController < Rho::RhoController

  FB_API_ID = "121263761311760" 
  FB_API_SECRET = "4eb7f3fa2cb42737d0a8b26b4fc5abf9"
  
  FB_AUTH_URL = "https://www.facebook.com/dialog/oauth"
  FB_GRAPH_URL = "https://graph.facebook.com"
  
  RHOMOBILE_FB_ID = "56638045891"
  
  RedirectServiceURL = "http://redirectme.to"
  
  def self.getRedirectURL(local_call_back_url)
    callback_url = RedirectServiceURL + "/" + '127.0.0.1:' + System.get_property('rhodes_port').to_s + local_call_back_url 
    return callback_url
  end
  
  def self.getFBAuthURL(local_call_back_url)
    call_back_url = getRedirectURL(local_call_back_url)
    #call_back_url goes unencoded since Facebook requires it to be like that, hence it goes at the end of the request
    url = "#{FB_AUTH_URL}?display=touch&client_id=#{FB_API_ID}&scope=user_likes&redirect_uri=#{call_back_url}"
    #url = "#{FB_AUTH_URL}?client_id=#{FB_API_ID}&scope=user_likes&redirect_uri=#{call_back_url}"
    return url
  end

  def self.getFBTokenURL(code, previous_call_back)
    call_back_url = getRedirectURL(previous_call_back) #This is not going to be called by facebook, it is just to certify you have access to the token by providing the SAME URL that was given when requesting the token
    #call_back_url goes unencoded since Facebook requires it to be like that, hence it goes at the end of the request
    url = "#{FB_GRAPH_URL}/oauth/access_token?client_id=#{FB_API_ID}&client_secret=#{FB_API_SECRET}&code=#{code}&redirect_uri=#{call_back_url}"
    return url
  end
    
  def self.getFBCheckLikeURL(token)
    url = "#{FB_GRAPH_URL}/me/likes/#{RHOMOBILE_FB_ID}?access_token=#{token}"
    return url
  end
  
  def index
    
  end
  
  def nothing
    
    return "{ }" #Empty json 
  end
  
  def connect_to_facebook
    local_callback_url = url_for(:action => :facebook_callback)
    url = FacebookConnectController.getFBAuthURL(local_callback_url)
    
    WebView.navigate(url)
  end
  
  def facebook_callback
    #This is to achieve the effect of the "connecting" page
    token_result = Rho::AsyncHttp.get(
    :url => 'http://127.0.0.1:' + System.get_property('rhodes_port').to_s + url_for(:action => :facebook_check, :query => {'code' => @params['code']}),
      :callback => url_for(:action => :nothing)
    )
    
    redirect :action => :connecting
  end
  
  def connecting
    
  end
  
  def facebook_check
    code = @params['code']
    
    token_url = FacebookConnectController.getFBTokenURL(code, url_for(:action => :facebook_callback))

    #Since the "connecting" view is being displayed, we do the calls synchronously      
    token_result = Rho::AsyncHttp.get(
      :url => token_url
    )
    
    if token_result['status'] == "ok"
      token = token_result['body'].split('&')[0].split('=')[1]
      likes_url = FacebookConnectController.getFBCheckLikeURL(token)
      likes_result = Rho::AsyncHttp.get(
        :url => likes_url
      )
      if likes_result['status'] == "ok"
        likes_data = Rho::JSON.parse(likes_result['body'])
        if likes_data['data'].count > 0
          #Like case
          WebView.navigate(url_for :action => :facebook_check_callback, :query => {'likes' => 'true'})
          return
        else
          #Don't like case
          WebView.navigate(url_for :action => :facebook_check_callback, :query => {'likes' => 'false'})
          return
        end
      end
    end
      
    Alert.show_popup( { 
                :message => "There was a problem contacting Facebook, please try again later.",
                :title => 'Error contacting Facebook',
                :icon => :error,
                :buttons => ["OK"] } )
    WebView.navigate ( url_for :action => :index )
  end
  
  def facebook_check_callback
    @message = nil
    if @params['likes'].to_s == 'true'
      @message = "You really like Rhomobile! Rock on!"
    else
      @message = "You don't like Rhomobile! Why?"
    end
  end
  
end