require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

configure do 
  enable :sessions
  set :session_secret, "031b4f80d19a0d17e05122db36ee493db4ec72ff6a8e0476152467c40f45ed73"
end

before do 
  session[:contacts] ||= []
end

helpers do 
  def get_contact_grammer(contact_number)
    contact_number == 1 ? 'contact' : 'contacts'
  end
end

# extracting contact info to edit
def get_contact_info(name, contacts)
  contacts.select do |contact| # passing in: { name: name, phone: phone, email: email, type: type, notes: notes }
    contact.has_value?(name)
  end.first
end

def sort_contact_by_type(contacts, sort_criteria)
  contacts.select { |contact| contact[:type] == sort_criteria }
end

# validate email format
def invalid_email?(email)
  return false if email.empty? #email entry is optional
  
  minus_at = email.split('@')
  clean_arr = minus_at.map do |el|
    el.split('.')
  end.flatten
  !(clean_arr.size == 3) #if email is entered, must have proper format( xxx@xxx.xxx)
end

# validate phone number
def invalid_phone?(number)
  number = number.gsub(/[^0-9a-zA-Z]/, '')
  number.size != 10 || number.to_i.to_s != number
end 

# name validation for new contact entry
def validate_new_name
  return "Must enter a valid name." if params[:name].empty?
  
  name_check = session[:contacts].any? do |contact| 
    contact[:name] == format_name(params[:name].to_s) 
  end

  return "Must enter a unique name." if name_check 
end

# name validation when contact already exists in session[:contact]
def validate_existing_name(contact)
  if contact[:name] == params[:new_name]
    return
  elsif params[:new_name].empty?
    return "Must enter a valid name."
  elsif session[:contacts].any? { |contact| contact[:name] == format_name(params[:new_name])}
    return "That contact name already exits."
  end
end

# validate all contact info (ohone, emial, type)
def validate_data
  case 
  when params[:phone].empty?
    then "Must enter a valid phone number."
  when invalid_phone?(params[:phone])
    then "Must enter a valid 10-digit phone number."
  when invalid_email?(params[:email])
    then "Must enter a valid email address."
  when params[:type].nil?
    then "Must choose a contact type."
  end
end

def format_name(name)
  name.split.map(&:capitalize).join(' ')
end

def format_phone(number)
  number = number.gsub(/[^0-9]/, '')
  number = number.chars.insert(3, '-')
  number = number.insert(7, '-')
  number.join
end

# view homepage
get '/' do
  @contact_number = session[:contacts].size 
  erb :home, layout: :layout
end

# view list of all contacts (sorted by name)
get '/contacts' do
  @contacts = session[:contacts].sort_by { |data| data[:name] }
  erb :contacts, layout: :layout
end

# form page to add new contact
get "/new" do 
  erb :new_contact, layout: :layout
end

get "/sort" do
  @sort_criteria = session[:sort_criteria]
  contacts = session[:contacts].sort_by { |data| data[:name] }

  @selected_contacts = sort_contact_by_type(contacts, @sort_criteria)
  erb :sort, layout: :layout
end

post "/sort" do 
  session[:sort_criteria] = params[:type]
  redirect "/sort"
end

post "/contacts/:name/delete" do 
  name = params[:name].to_s
  contacts = session[:contacts]
  contact = get_contact_info(name, contacts) #target hash

  contacts.delete(contact)
  session[:message] = "#{name} has been deleted from your contact list."
  redirect '/contacts'
end

# adding a new contact
post "/contacts" do
  name_error = validate_new_name
  data_error = validate_data 
  
  if name_error
    session[:message] = name_error
    erb :new_contact, layout: :layout
  elsif data_error
    session[:message] = data_error
    erb :new_contact, layout: :layout
  else
    name = format_name(params[:name].to_s)
    phone = format_phone(params[:phone].to_s)
    email = params[:email]
    type = params[:type]
    notes = params[:notes]

    session[:contacts] << { name: name, phone: phone, email: email, type: type, notes: notes }
    session[:message] = "#{name} has been added to your contact list."
    redirect '/contacts'
  end
end

# editing existing contact information
get "/contacts/:name/edit" do
  name = params[:name].to_s
  contacts = session[:contacts]
  @contact = get_contact_info(name, contacts)

  erb :edit_contact, layout: :layout
end

#view contact data
get "/contacts/:name" do 
  name = params[:name].to_s
  contacts = session[:contacts]
  @contact = get_contact_info(name, contacts)

  erb :contact, layout: :layout
end 

# updating contact information
post "/contacts/:name" do 
  name = params[:name].to_s
  contacts = session[:contacts]
  @contact = get_contact_info(name, contacts)

  name_error = validate_existing_name(@contact)
  data_error = validate_data
    
  if name_error
    session[:message] = name_error
    erb :edit_contact, layout: :layout
  elsif data_error
    session[:message] = data_error
    erb :edit_contact, layout: :layout
  else
    @contact[:name] = format_name( params[:new_name].to_s || @contact[:name] )
    @contact[:phone] = params[:phone]
    @contact[:email] = params[:email]
    @contact[:type] = params[:type]
    @contact[:notes] = params[:notes]

    session[:message] = "#{@contact[:name]}'s information has been updated."
    redirect '/'
  end
end
