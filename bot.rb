require 'discordrb'
require 'oauth2'
require 'mysql'
require 'mongo'
require 'webshot'
require 'net/http'
require 'uri'
require 'json'

begin
  # connexion au serveur MySQL
  $dbh = Mysql.real_connect(SERVER, ACCOUNT, PSSW, BDD)
  # récupère la chaîne de version du serveur et l'affiche
  puts "Version du serveur: " + $dbh.get_server_info
rescue Mysql::Error => e
  puts "Code d'erreur : #{e.errno}"
  puts "Message d'erreur : #{e.error}"
  puts "SQLSTATE d'erreur : #{e.sqlstate}" if e.respond_to?("sqlstate")
end

save = {}
sgroup = {}
begin
  File.open("save.42") do |f|
    save = Marshal.load(f)
  end
rescue Exception
  puts "Impossible de lire le fichier de save.42, il est surement vide."
end

begin
File.open("group.42") do |f|
  sgroup = Marshal.load(f)
end
rescue Exception
  puts "Impossible de lire le fichier de group.42, il est surement vide."
end

client_m = Mongo::Client.new(['localhost:27017'], :database => 'h-42bots')

bot = Discordrb::Commands::CommandBot.new token: TOKEN, client_id: CLIENT_ID, prefix: '42'

FTSERVER_CHN_ID = 534600761288556546

require "oauth2"
UID = UID
SECRET = SECRET
client = OAuth2::Client.new(UID, SECRET, site: "https://api.intra.42.fr")
token = client.client_credentials.get_token

bot.ready do |event|
	puts 'READY'
	collection = client_m[:exam]
	collection.insert_one({ type: :exam_id, exam_id: 0 }) unless collection.find(type: :exam_id).count >= 1
end

def is_login? (event, token: false)
	res = $dbh.query("SELECT * FROM 42users WHERE discordid = #{event.user.id}")
	return true if res.fetch_row
	event.respond "Erreur, votre compte Discord n'est pas dans notre bdd des utilisateurs 42. Pour y remédier, allez sur ce lien : https://bit.ly/2Nej5eJ" if token == false
	false
end

def get_login (id)
	res = $dbh.query("SELECT * FROM 42users WHERE discordid = #{id}")
	rtn = res.fetch_row
	return rtn[1] if rtn
	false
end

def login (event)
	res = $dbh.query("SELECT * FROM 42users WHERE discordid = #{event.user.id}")
	return true if res.fetch_row
	false
end

def init_cmd (event)
	return false unless security_check(event)
	where_rsp(event)
end

def where_rsp (event)
	return { channel: event.channel, status: :channel } if event.channel.id == FTSERVER_CHN_ID
	{ channel: event.user.pm, status: :pm }
end

def security_check (event)
	refresh_check = refresh_user_token(event)
	if refresh_check[:status] == :error
		event.respond refresh_check[:reason]
		return false
	end
	if is_close?(refresh_check[:status])
		event.respond "Erreur, votre compte 42 est innacesible."
		return false
	end
	true
end

def refresh_user_token (event)
	res = $dbh.query("SELECT * FROM 42users WHERE discordid = #{event.user.id}")
	rtn = res.fetch_row
	return { status: :error, reason: "Il semble que vous ne soyez pas dans notre bdd." } unless rtn
	refresh_old = rtn[2]
	uri = URI.parse("https://api.intra.42.fr/oauth/token")
	request = Net::HTTP::Post.new(uri)
	request.set_form_data(
		"client_id" => UID,
		"grant_type" => "refresh_token",
		"refresh_token" => refresh_old,
	)
	req_options = {
		use_ssl: uri.scheme == "https",
	}
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
		http.request(request)
	end
	return { status: :error, reason: "Impossible de Regénérer votre token. 
		Sois vous devez vous re connecter a nouveau, sois votre compte 42 est 
		innacesible. Vous pouvez tentez de vous re connecter via la commande : 
		42refresh." } unless response.code == '200'
	r_parsed = JSON.parse(response.body)
	$dbh.query("UPDATE 42users SET refresh_token = '#{r_parsed["refresh_token"]}' WHERE discordid = #{event.user.id}")
	{ status: r_parsed["access_token"], reason: 'granted' }
end

def is_close? (user_token)
	uri = URI.parse("https://api.intra.42.fr/oauth/token/info")
	request = Net::HTTP::Get.new(uri)
	request["Authorization"] = "Bearer #{user_token}"
	req_options = {
		use_ssl: uri.scheme == "https",
	}
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
		http.request(request)
	end
	return true unless response.code == '200'
	false
end

def reply(msg, cmd_state, event)
	if cmd_state[:status] == :pm
		event.respond "Envois des informations par message privées."
		cmd_state[:channel].send msg
	elsif cmd_state[:status] == :channel
		cmd_state[:channel].send msg
	end
end

bot.command(:whois, min_args: 1) do |event, user, *args|
	return unless cmd_state = init_cmd(event)
	args = "#{user} #{args.join(' ')}" if args.any?
	if user_mention = event.message.mentions[0]
		login = get_login(user_mention.id)
	end
	unless args.is_a? String
		finded_user = bot.find_user(user)
	else
		finded_user = bot.find_user(args)
	end
	login = get_login(finded_user[0].id) if finded_user.any?
	if login == false
		reply("Login non trouve", cmd_state, event)
	else
		reply("Le login est : #{login}", cmd_state, event)
	end
end

=begin
bot.command(:cluster, min_args: 1, max_args: 1) do |event, cluster|
	return unless cmd_state = init_cmd(event)
	screenshot = Webshot::Screenshot.instance
	case cluster.capitalize
	when "E1"
		screenshot.capture "http://clusters.42.fr/1", "cluster_1.png", width: 2048, height: 2200
		bot.send_file(event.channel.id, File.open('cluster_1.png', 'r'))
	when "E2"
		screenshot.capture "http://clusters.42.fr/2", "cluster_2.png", width: 2048, height: 2200
		bot.send_file(event.channel.id, File.open('cluster_2.png', 'r'))
	when "E3"
		screenshot.capture "http://clusters.42.fr/3", "cluster_3.png", width: 2048, height: 2200
		bot.send_file(event.channel.id, File.open('cluster_3.png', 'r'))
	else
		event.respond "Erreur, ce cluster n'existe pas."
	end
bot.command(:cluster, min_args: 1, max_args: 1) do |event, cluster|
	screenshot = Webshot::Screenshot.instance
	case cluster.capitalize
	when "E1"
		screenshot.capture "http://clusters.42.fr/1", "cluster_1.png", width: 2048, height: 2200
		bot.send_file(event.channel.id, File.open('cluster_1.png', 'r'))
	when "E2"
		screenshot.capture "http://clusters.42.fr/2", "cluster_2.png", width: 2048, height: 2200
		bot.send_file(event.channel.id, File.open('cluster_2.png', 'r'))
	when "E3"
		screenshot.capture "http://clusters.42.fr/3", "cluster_3.png", width: 2048, height: 2200
		bot.send_file(event.channel.id, File.open('cluster_3.png', 'r'))
	else
		event.respond "Erreur, ce cluster n'existe pas."
	end
end
=end
bot.command(:notif_exam) do |event|
	return unless is_login?(event)
	return unless cmd_state = init_cmd(event)
	user_f_state = :not_defined
	collection = client_m[:exam]
	c_user = collection.find(user: event.user.id)
	if c_user.count >= 1
		if c_user.first[:status]
			collection.update_one({ user: event.user.id }, { '$set' => { status: false } })
			user_f_state = :false
		else
			collection.update_one({ user: event.user.id }, { '$set' => { status: true } })
			user_f_state = :true
		end
	else
		collection.insert_one({ user: event.user.id, status: true })
		user_f_state = :true
	end
	reply("Votre inscription de notification aux sorties d'exams a bien été mise sur : #{user_f_state}", cmd_state, event)
end



def send_exam_embed(user, infoexam)
	img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
	dt = infoexam["begin_at"]
	dd = dt.split('T')
	date = dd[0].split('-')
	user.pm.send_embed do |embed|
		embed.title = "Exam @42"
		embed.description = 'Exam du ' + date[2] + "/" + date[1] + "/" + date[0]
		embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: 'Ecole 42')
		embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
		embed.add_field(name: 'NB places', value: infoexam["max_people"]).to_s
		embed.add_field(name: 'NB restante', value: infoexam["max_people"].to_i - infoexam["nbr_subscribers"].to_i).to_s
		embed.add_field(name: 'Location', value: infoexam["location"]).to_s
	end
end

def notif_exam(client_m, bot, token)
	info_exam = token.get("/v2/campus/1/cursus/1/exams").parsed[0]
	collection = client_m[:exam]
	return if info_exam["id"].to_i == collection.find(type: :exam_id).first[:exam_id]
	collection.update_one({ type: :exam_id }, { '$set' => { exam_id: info_exam["id"].to_i } })
	collection.find(status: true).each do |n_u|
		begin
			bot.user(n_u[:user]).pm "**Un Exam vient d'apparaitre sur l'intra :**"
			send_exam_embed(bot.user(n_u[:user]), info_exam)
		rescue StandardError => e
			puts e.inspect
			puts e.class
			next
		end
	end
end

bot.heartbeat do ||
    client = OAuth2::Client.new(UID, SECRET, site: "https://api.intra.42.fr")
    token = client.client_credentials.get_token
    bot.game = "42help"
    begin
  # connexion au serveur MySQL
  $dbh = Mysql.real_connect(SERVER, ACCOUNT, PSSW, BDD)
  # r  cup  re la cha  ne de version du serveur et l'affiche
  #puts "Version du serveur: " + $dbh.get_server_info
rescue Mysql::Error => e
  puts "Code d'erreur : #{e.errno}"
  puts "Message d'erreur : #{e.error}"
  puts "SQLSTATE d'erreur : #{e.sqlstate}" if e.respond_to?("sqlstate")
end
	notif_exam(client_m, bot, token)
   # bot.servers.each do |s|
#	puts s.to_s
 #       s[1].users.each do |p|
  #        puts "-> " + p.name
   #     end
    #end
    nil
end


bot.command(:invit, max_args: 0, min_args: 0, usage: "invit", description: "Lien d'invitation du bot") do |event|
  event.respond "https://discordapp.com/oauth2/authorize?&client_id=388110639220129813&scope=bot&permissions=0"
end

bot.command(:source, max_args: 0, min_args: 0, usage: "source", description: "Lien du code source") do |event|
  event.respond "https://github.com/Asandolo/42bots"
end

bot.command(:phone, usage: "phone <xlogin>", min_args: 1, description: "Permet d'afficher le numéro de téléphone d'un utilisateur") do |event, login|
	return if !is_login? event
	return unless cmd_state = init_cmd(event)
	infophone = token.get("/v2/users/" + login).parsed
	img = infophone["image_url"]
	phone = "Aucun" unless infophone["phone"]
	phone = infophone["phone"] unless phone == "Aucun"
	event.respond "Envoi des informations par message privé." if cmd_state[:status] == :pm
	cmd_state[:channel].send_embed do |em|
		em.title = "Numéro de téléphone de #{infophone['displayname']}"
		em.url = "https://profile.intra.42.fr/users/#{login}"
		em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
		em.author = Discordrb::Webhooks::EmbedAuthor.new(name: "Phone")
		em.colour = "#59677f"
		em.add_field(name: "**Numéro :**", value: phone)
	end
	nil
end

bot.command(:event, usage: "event", description: "Permet de voirs les event a venir et en cours a 42.") do |event|
	return if !is_login? event
	return unless cmd_state = init_cmd(event)
	infoevent = token.get("/v2/campus/1/events").parsed
	i = 0
	img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
	event.respond "Envoi des informations par message privé." if cmd_state[:status] == :pm
	cmd_state[:channel].send_embed do |em|
		em.title = 'Prochains events a 42'
		em.url = "https://profile.intra.42.fr/events"
		em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
		em.author = Discordrb::Webhooks::EmbedAuthor.new(name: "Events")
		em.colour = "#23db35"
		infoevent.each do |v|
			break if i == 5
			em.add_field(name: v['name'], value: "**Emplacement :** #{v['location']}, **Type** : #{v['kind']}, **Commence le** #{v['begin_at']} et **finis le** #{v['end_at']} **Il reste encore** #{v['max_people'].to_i - v['nbr_subscribers'].to_i} **places**. **Lien :** https://profile.intra.42.fr/events/#{v['id']}")
			i += 1
		end
	end
	nil
end

bot.command(:shop, usage: "shop", description: "Permets de voirs les produits en vente dans le shop de 42.") do |event|
	return if !is_login? event
	return unless cmd_state = init_cmd(event)
	infoshop = token.get("v2/campus/1/products").parsed
	img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png' 
	event.respond "Envoi des informations par message privé." if cmd_state[:status] == :pm
	cmd_state[:channel].send_embed do |em|
		em.title = "Produits dans le shop de 42"
		em.url = "https://shop.intra.42.fr"
		em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
		em.author = Discordrb::Webhooks::EmbedAuthor.new(name: "Shop")
		em.colour = "1e26c9"
		infoshop.each do |v|
			stock = v['quantity']
			stock = "Infinis" if stock.nil?
			em.add_field(name: v['name'], value: "**Prix :** #{v['price']} ₳, **Stock :** #{stock}.")
		end
	end
end


bot.command(:botdevs, usage: 'botdevs', description: "Inutile, totalement.") do |event|
	return unless cmd_state = init_cmd(event)
	bot.commands[:user].call(event, ['asandolo'])
	bot.commands[:user].call(event, ['ebertin'])
	nil
end


bot.command(:achievements, max_args: 1, min_args: 0, usage: "achievements [xlogin]", description: "voir les archievement") do |event, login|
  return if !is_login? event
  return unless cmd_state = init_cmd(event)
  login = get_login event.user.id if login == nil
  img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
  infouser = token.get("/v2/users/" + login).parsed
  event.respond "Envoi des informations par message privé." if cmd_state[:status] == :pm
  cmd_state[:channel].send_embed do |em|
    em.title = 'Archivements de ' + infouser["displayname"].to_s
    em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
    infouser["achievements"].each do |info|
      em.add_field(name: info["name"].to_s , value: info["description"].to_s)
      end
  end
  nil
end

bot.command(:savegroup, min_args: 1, usage: "savegroup xlogin ...", description: "Permet d'ajouter 1 ou plusieurs utilisateurs a votre groupe.") do |event, *args|
  return unless cmd_state = init_cmd(event)
  if sgroup[event.user.id] == nil
    sgroup[event.user.id] = []
  end
    args.each do |use|
	begin
      if token.get("/v2/users/" + use).parsed != nil
        sgroup[event.user.id] << [use]
        File.open("group.42", "w") do |f|
          Marshal.dump(sgroup, f)
        end
      else
        event.respond use + " n'est pas enregistré dans la base de donnés de 42 !"
      end
	  rescue Exception
		nil
	  end
	  nil
   end
  event.respond "La commande a bien été réalisé !"
end

bot.command(:infogroup, usage: "infogroup", description: "Permet de voir les utilisateurs que vous avez choisis d'ajouter a votre groupe.") do |event|
  return unless cmd_state = init_cmd(event)
  if sgroup[event.user.id] == nil
    sgroup[event.user.id] = []
  end
  event.respond sgroup[event.user.id].to_s
end

bot.command(:deletegroup, min_args: 1, usage: "deletegroup xlogin ...", description: "Permet de supprimer 1 ou plusieurs utilisateurs de votre groupe.") do |event, *args|
  return unless cmd_state = init_cmd(event)
  if sgroup[event.user.id] == nil
    sgroup[event.user.id] = []
  end
    if sgroup[event.user.id] != []
      args.each do |del|
        sgroup[event.user.id].delete([del])
        File.open("group.42", "w") do |f|
          Marshal.dump(sgroup, f)
        end
      end
      event.respond "La commande a bien été réalisé !"
    else
      "Erreur, votre groupe est vide !"
    end
  nil
end

bot.command(:group, usage: "old_group", description: "Permet d'afficher les utilisateurs de votre groupe. Cela vous permet avec une seule commande d'avoir des informations sur tout voutre groupe de travail, ce qui faut l'avouer est bien pratique.") do |event|
  return unless cmd_state = init_cmd(event)
  if sgroup[event.user.id] == nil
    sgroup[event.user.id] = []
  end
  if sgroup[event.user.id] != []
    event.user.pm.send_embed do |embed|
        embed.title = event.user.name + " " + sgroup[event.user.id].size.to_s
        embed.colour = "#4180db"
        embed.description = 'Groupe de ' + event.user.name
        embed.add_field(name: '--------------------', value:'--------------------')
        embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: 'Ecole 42')
        embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png')
        sgroup[event.user.id].each do |use|
          usenew = token.get("/v2/users/" + use[0]).parsed
          embed.add_field(name: use[0], value: "Informations sur " + use[0])
          if usenew["location"] != nil
            embed.add_field(name: 'Location', value: usenew["location"].to_s)
          else
            embed.add_field(name: 'Location', value: 'Unavailable')
          end
          embed.add_field(name: 'Wallet', value: usenew["wallet"].to_s)
          embed.add_field(name: 'lvl / grade :', value: usenew["cursus_users"][0]["level"].to_s + " / " + usenew["cursus_users"][0]["grade"].to_s)
          embed.add_field(name: '--------------------', value:'--------------------')
        end
    end
  else
    "Erreur, votre groupe est vide !"
  end
  nil
end

bot.command(:group, usage: "group", description: "Permet d'afficher les utilisateurs de votre groupe. Cela vous permet avec une seule commande d'avoir des informations sur tout voutre groupe de travail, ce qui faut l'avouer est bien pratique.") do |event|
  return unless cmd_state = init_cmd(event)
  if sgroup[event.user.id] == nil
    sgroup[event.user.id] = []
  end
  event.respond "Envoi des informations par message privé."
  if sgroup[event.user.id] != []
    new_embed(event, sgroup, token)
  else
    "Erreur, votre groupe est vide !"
  end
  nil
end


def new_embed(event, sgroupc, token)
     event.user.pm.send_embed do |embed|
        embed.title = event.user.name
        embed.colour = "#4180db"
        embed.description = 'Groupe de ' + event.user.name
        embed.add_field(name: '--------------------', value:'--------------------')
        embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: 'Ecole 42')
        embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png')
        sgroupc[event.user.id].each_with_index do |use, i|
	if (i == 5)
	    tmp = {}
	    tmp[event.user.id] = sgroupc[event.user.id]
	    tmp[event.user.id] = []
	    sgroupc[event.user.id].each do |e|
  		tmp[event.user.id] << e.clone
            end
            tmp[event.user.id].delete_at(0)
	    tmp[event.user.id].delete_at(0)
	    tmp[event.user.id].delete_at(0)
            tmp[event.user.id].delete_at(0)
            tmp[event.user.id].delete_at(0)	  
	    new_embed(event, tmp, token)
	end
          usenew = token.get("/v2/users/" + use[0]).parsed
          embed.add_field(name: use[0], value: "Informations sur " + use[0])
          if usenew["location"] != nil
            embed.add_field(name: 'Location', value: usenew["location"].to_s)
          else
            embed.add_field(name: 'Location', value: 'Unavailable')
          end
          embed.add_field(name: 'Wallet', value: usenew["wallet"].to_s)
          embed.add_field(name: 'lvl / grade :', value: usenew["cursus_users"][0]["level"].to_s + " / " + usenew["cursus_users"][0]["grade"].to_s)
          embed.add_field(name: '--------------------', value:'--------------------')
        end
    end
end


bot.command(:project, max_args: 1, min_args: 0, usage: "project [xlogin]", description: "") do |event, login|
  return if !is_login? event
  return unless cmd_state = init_cmd(event)
  if login == nil
    login = get_login event.user.id
  end
  img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
  infouser = token.get("/v2/users/" + login).parsed
  event.respond "Envoi des informations par message privé." if cmd_state[:status] == :pm
  cmd_state[:channel].send_embed do |em|
    em.title = 'Projets de ' + infouser["displayname"].to_s
    em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
    projectf = ""
    projecti = ""
    infouser["projects_users"].each do |info|
      if info["cursus_ids"][0].to_i == 1 && info["status"].to_s == "finished"
        projectf += "" + info["project"]["name"].to_s
        if info["occurrence"].to_i > 0
          projectf += " retry " + info["occurrence"].to_s + " times "
        else
          projectf += " no retry "
        end
        if info["final_mark"] != nil
          projectf += "Final mark " + info["final_mark"].to_s
        end
        projectf += "\n"
        else if info["cursus_ids"][0].to_i == 1 && info["status"].to_s == "in_progress"
               projecti += "" + info["project"]["name"].to_s
               if info["occurrence"].to_i > 0
                 projecti += " retry " + info["occurrence"].to_s + " times \n"
              else
                projecti += " no retry \n"
               end
             end
      end
    end
    em.add_field(name: 'projets finished :', value: projectf)
    em.add_field(name: 'projets in progress :', value: projecti)
  end
  nil
end


bot.command(:extended_project, max_args: 1, min_args: 0, usage: "extended_project [xlogin]", description: "") do |event, login|
  return if !is_login? event
  return unless cmd_state = init_cmd(event)
  if login == nil
    login = get_login event.user.id
  end
  img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
  infouser = token.get("/v2/users/" + login).parsed
  event.respond "Envoi des informations par message privé." if cmd_state[:status] == :pm
  cmd_state[:channel].send_embed do |em|
    em.title = 'Projets de ' + infouser["displayname"].to_s
    em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
    projectf = ""
    projecti = ""
    i = 0
    infouser["projects_users"].each do |info|
    i = i + 1
    break if i == 2
      if info["cursus_ids"][0].to_i == 6 && info["status"].to_s == "finished"
        projectf += "" + info["project"]["name"].to_s
        if info["occurrence"].to_i > 0
          projectf += " retry " + info["occurrence"].to_s + " times "
        else
          projectf += " no retry "
        end
        if info["final_mark"] != nil
          projectf += "Final mark " + info["final_mark"].to_s
        end
        projectf += "\n"
       else if info["cursus_ids"][0].to_i == 6 && info["status"].to_s == "in_progress"
               projecti += "" + info["project"]["name"].to_s
               if info["occurrence"].to_i > 0
                 projecti += " retry " + info["occurrence"].to_s + " times \n"
               else
                 projecti += " no retry \n"
               end
             end
      end
    end
    em.add_field(name: 'projets finished :', value: projectf)
    em.add_field(name: 'projets in progress :', value: projecti)
  end
  nil
end


bot.command(:examuser, min_args: 0, max_args: 1, usage: "examusers <xlogin>", description: "") do |event, login|
	i = 0
	if login == nil
		login = get_login event.user.id if login event
	end
	return unless cmd_state = init_cmd(event)
	return event.respond "Erreur, veuillez préciser un utilisateur ou vous enregistrer sur : https://bit.ly/2Nej5eJ" if login == nil
	if login != nil
		begin
			infouser = token.get("/v2/users/" + login + "/projects_users?filter[project_id]=11" ).parsed
		rescue StandardError
			event.respond "Erreur, cet utilisateur n'existe pas."
			return
		end
		infouser[0]["teams"].each do |t|
			if t["final_mark"].to_i >= 75
				i += 1
			end
		end
		event.respond "Envois des informations par messages privées." if cmd_state[:status] == :pm
		cmd_state[:channel].send_embed do |embed|
			embed.title = "Exam"
			embed.description = 'Exam de ' + login
			embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: 'Ecole 42' )
			embed.add_field(name: 'Note Final', value: infouser[0]["final_mark"]).to_s
			embed.add_field(name: 'Try', value: infouser[0]["occurrence"]).to_s
			if i >= 1
				embed.add_field(name: 'Exam 1', value:  "validated")
			else
				embed.add_field(name: 'Exam 1', value:  "No validated")
			end
                        if i >= 2
                                embed.add_field(name: 'Exam 2', value:  "validated")
                        else
                                embed.add_field(name: 'Exam 2', value:  "No validated")
                        end
                        if i >= 3
                                embed.add_field(name: 'Exam 3', value:  "validated")
                        else
                                embed.add_field(name: 'Exam 3', value:  "No validated")
                        end
                        if i >= 4
                                embed.add_field(name: 'Exam 4', value:  "validated")
                        else
                                embed.add_field(name: 'Exam 4', value:  "No validated")
                        end
                        if i >= 5
                                embed.add_field(name: 'Exam 5', value:  "validated")
                        else
                                embed.add_field(name: 'Exam 5', value:  "No validated")
                        end
	end
  nil
	end
end

bot.command(:exam, max_args: 1, min_args: 0, usage: "exam [101]", description: "") do |event, campus|
  return unless cmd_state = init_cmd(event)
  if campus == '101'
    c = '9'
    campus = 'le 101'
    img = 'https://cdn.discordapp.com/attachments/311550158464614400/388743245795950604/logo-101.png'
  else
    c = '1'
    campus = '42'
    img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
  end
  infoexam = token.get("/v2/campus/" + c + "/cursus/1/exams").parsed
  puts infoexam[0]
  dt = infoexam[0]["begin_at"]
  dd = dt.split('T')
  date = dd[0].split('-')
  event.respond "Envois des informations par messages privées." if cmd_state[:status] == :pm
  cmd_state[:channel].send_embed do |embed|
    embed.title = "Exam @" + campus
    embed.description = 'Exam du ' + date[2] + "/" + date[1] + "/" + date[0]
    embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: 'Ecole ' + campus)
    embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
    embed.add_field(name: 'NB places', value: infoexam[0]["max_people"]).to_s
    embed.add_field(name: 'NB restante', value: infoexam[0]["max_people"].to_i - infoexam[0]["nbr_subscribers"].to_i).to_s
    embed.add_field(name: 'Location', value: infoexam[0]["location"]).to_s
  end
  nil
end

bot.command(:raw_user, max_args: 1, min_args: 0, usage: "raw_user <xlogin>", description: "Permet de récupérer des informations bruts sur un utilisateur.") do |event, login|
	return if !is_login? event
	return unless cmd_state = init_cmd(event)
	login = get_login event.user.id if login == nil
	begin
		infouser = token.get("/v2/users/#{login}").parsed
	rescue StandardError
		event.respond "Erreur, cet utilisateur n'existe pas."
		return
	end
	puts 1
	arr_msg = JSON.pretty_generate(infouser).to_s
	puts 2
	arr_msg = Discordrb.split_message(arr_msg)
	puts 3
	event.respond "Envoi des informations par message privé."
	puts 4
	arr_msg.each { |msg| event.user.pm "```JSON\n#{msg}\n```" }
	puts 5
	nil
end

bot.command(:quest, help_available: false) do |event, login|
	return unless cmd_state = init_cmd(event)
	puts infoquest = token.get("/v2/users/#{login}/quests_users").parsed
	event.respond "Envois des informations par message privées." if cmd_state[:status] == :pm
	infoquest.each { |a| cmd_state[:channel].send a["quest"].to_s if [3, 2, 1].include?(a["quest_id"]) && !a["validated_at"].nil? }
	nil
end


bot.command(:user, min_args: 0, usage: "user <xlogin>", description: "") do |event, login, *args|
	return unless cmd_state = init_cmd(event)
	str = " "
	args = "#{login} #{args.join(' ')}" if args.any?
	if login
		finded_user = bot.find_user(login) unless args.is_a? String
		finded_user = bot.find_user(args) if args.is_a? String
		login = get_login(finded_user[0].id) if finded_user.any?
	end
	if user_mention = event.message.mentions[0]
		login = get_login(user_mention.id)
	end
	if login == nil
		login = get_login event.user.id if login event
	end
	return event.respond "Erreur, veuillez préciser un utilisateur ou vous enregistrer sur : https://bit.ly/2Nej5eJ" if login == nil
	if login != nil
	begin
		infouser = token.get("/v2/users/" + login).parsed
	rescue StandardError
		event.respond "Erreur, cet utilisateur n'existe pas."
		return
	end
	coauser = token.get("/v2/users/" +  login + "/coalitions").parsed
	coa = coauser.last
	#begin
	#return
	event.respond "Envois des informations par messages privées." if cmd_state[:status] == :pm
	cmd_state[:channel].send_embed do |embed|
		embed.title = infouser["displayname"].to_s
		embed.image = Discordrb::Webhooks::EmbedImage.new(url: infouser["image_url"].to_s )
		if coauser[0] != nil
			embed.colour = coa["color"].to_s
		else
			embed.colour = "#5c5c5c"
		end
		embed.description = 'Informations de ' + infouser["displayname"].to_s
		embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: 'Ecole 42')
		embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png')
		embed.url = "http://profile.intra.42.fr/users/" + infouser["login"].to_s
		embed.add_field(name: "Dev" , value: " I am a 42bots developer") if infouser["login"] == "asandolo"|| infouser["login"] == "ebertin"
		if infouser["groups"].size != 0
			grp = infouser["groups"]
			grp.each do |g|
				str += " " + g["name"]
			end
			embed.add_field(name: 'Groups' , value: str.strip)
		end

		if (infouser["pool_month"] != nil && infouser["pool_year"] != nil)
			embed.add_field(name: 'Piscine', value: infouser["pool_month"].to_s + " " + infouser["pool_year"])
		end
		if infouser["staff?"]==true
			embed.add_field(name: 'Staff' , value: "I am a Staff member !")
		end
		if infouser["location"] != nil
          embed.add_field(name: 'Location', value: infouser["location"].to_s)
        else
          embed.add_field(name: 'Location', value: 'Unavailable')
        end
        embed.add_field(name: 'Wallet', value: infouser["wallet"].to_s)
        embed.add_field(name: 'lvl / grade :', value: infouser["cursus_users"][0]["level"].to_s + " / " + infouser["cursus_users"][0]["grade"].to_s)
      end
    #rescue Exception
      # puts "Une Erreur c'est produite dans l'envois d'un des messages."
    #end
  else
    event.respond "Merci de preciser un login !"
  end
  nil
end

bot.command(:save, usage: "save <xlogin>", description: "Permet de d'identifier votre compte 42.") do |event, log|
  event.respond "Pour vous enregister, vous pouvez vous rendre sur ce lien : https://bit.ly/2Nej5eJ"
end


bot.command(:coa, max_args: 1, min_args: 0, usage: "<coa 101|pool>", description: "") do |event, arg|
	return unless cmd_state = init_cmd(event)
	unless arg.nil?
		if arg == "101"
			bloc = 8
			nb = 3
		elsif arg == "pool"
			bloc = 3
			nb = 4
		elsif arg == "42"
			bloc = 1
			nb = 4
		else
			bloc = 1
			nb = 4
		end
	else
		bloc = 1
		nb = 4
	end
	
	infocoa = token.get("/v2/blocs/" + bloc.to_s + "/coalitions").parsed

	infocoa.sort! { |a, b| b["score"].to_i <=> a["score"].to_i }

	puts infocoa.inspect

	if bloc == 1
		bloc_1_al = "https://cdn.discordapp.com/attachments/343069792829308928/515207150394540053/unknown.png"
		bloc_1_fe = "https://cdn.discordapp.com/attachments/343069792829308928/515206968093310997/unknown.png"
		bloc_1_or = "https://cdn.discordapp.com/attachments/343069792829308928/515207098217529350/unknown.png"
		bloc_1_as = "https://cdn.discordapp.com/attachments/343069792829308928/515206896563519519/unknown.png"
		if infocoa[0]["slug"] == "the-order"
			image = bloc_1_or
		elsif infocoa[0]["slug"] == "the-alliance"
			image = bloc_1_al
		elsif infocoa[0]["slug"] == "the-federation"
			image = bloc_1_fe
		else
			image = bloc_1_as
		end
	elsif bloc == 3
		bloc_3_bl = "https://cdn.discordapp.com/attachments/315430063728361472/464158581126594570/unknown.png"
		bloc_3_sk = "https://cdn.discordapp.com/attachments/315430063728361472/464158523199062027/unknown.png"
		bloc_3_sl = "https://cdn.discordapp.com/attachments/315430063728361472/464158628505714698/unknown.png"
		bloc_3_wo = "https://cdn.discordapp.com/attachments/315430063728361472/464158408174469120/unknown.png"
		if infocoa[0]["slug"] == "the-blobfish"
			image = bloc_3_bl
		elsif infocoa[0]["slug"] == "the-skunks"
			image = bloc_3_sk
		elsif infocoa[0]["slug"] == "the-sloths"
			image = bloc_3_sl
		else
			image = bloc_3_wo
		end
	elsif bloc == 8
		bloc_8_pi = "https://cdn.discordapp.com/attachments/343069792829308928/515265481809330187/unknown.png"
		bloc_8_ex = "https://cdn.discordapp.com/attachments/343069792829308928/515265601984397322/unknown.png"
		bloc_8_ra = "https://cdn.discordapp.com/attachments/343069792829308928/515265786546487296/unknown.png"
		if infocoa[0]["slug"] == "pioneer"
			image = bloc_8_pi
		elsif infocoa[0]["slug"] == "explorer"
			image = bloc_8_ex
		else
			image = bloc_8_ra
		end
	else
		bloc_1_al = "https://cdn.discordapp.com/attachments/343069792829308928/515207150394540053/unknown.png"
		bloc_1_fe = "https://cdn.discordapp.com/attachments/343069792829308928/515206968093310997/unknown.png"
		bloc_1_or = "https://cdn.discordapp.com/attachments/343069792829308928/515207098217529350/unknown.png"
		bloc_1_as = "https://cdn.discordapp.com/attachments/343069792829308928/515206896563519519/unknown.png"
		if infocoa[0]["slug"] == "the-order"
			image = bloc_1_or
		elsif infocoa[0]["slug"] == "the-alliance"
			image = bloc_1_al
		elsif infocoa[0]["slug"] == "the-federation"
			image = bloc_1_fe
		else
			image = bloc_1_as
		end
	end
	event.respond "Envois des informations par messages privées." if cmd_state[:status] == :pm
	if nb == 3
		cmd_state[:channel].send_embed do |em|
			em.title = "Classement des coalitions"
			em.colour = infocoa[0]["color"]
			em.url = "https://profile.intra.42.fr/blocs/" + bloc.to_s + "/coalitions"
			em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: image)
			em.add_field(name: 'premier :', value: infocoa[0]["name"].to_s + ' score ' + infocoa[0]["score"].to_s)
			em.add_field(name: 'Deuxieme :', value: infocoa[1]["name"].to_s + ' score ' + infocoa[1]["score"].to_s)
			em.add_field(name: 'Dernier :', value: infocoa[2]["name"].to_s + ' score ' + infocoa[2]["score"].to_s)
		end
	else
		cmd_state[:channel].send_embed do |em|
			em.title = "Classement des coalitions"
			em.colour = infocoa[0]["color"]
			em.url = "https://profile.intra.42.fr/blocs/" + bloc.to_s + "/coalitions"
			em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: image)
			em.add_field(name: 'premier :', value: infocoa[0]["name"].to_s + ' score ' + infocoa[0]["score"].to_s)
			em.add_field(name: 'Deuxieme :', value: infocoa[1]["name"].to_s + ' score ' + infocoa[1]["score"].to_s)
			em.add_field(name: 'Troisieme :', value: infocoa[2]["name"].to_s + ' score ' + infocoa[2]["score"].to_s)
			em.add_field(name: 'Dernier :', value: infocoa[3]["name"].to_s + ' score ' + infocoa[3]["score"].to_s)
        end
	end
  nil
end


bot.message_edit do |event|
	args = event.message.content.split(' ')
	args.delete_at(0)
	bot.commands.each_key do |key|
		bot.commands[key].call(event, args) if event.message.content.scan(/^42#{Regexp.quote(key)}/).count > 0
	end
	nil
end

bot.run
