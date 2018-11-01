require 'discordrb'
require 'oauth2'
require 'mysql'

begin
  # connexion au serveur MySQL
  $dbh = Mysql.real_connect(SQL_HOST, LOGIN, PASSWORD, '42users')
  # récupère la chaîne de version du serveur et l'affiche
  puts "Version du serveur: " + $dbh.get_server_info
rescue Mysql::Error => e
  puts "Code d'erreur : #{e.errno}"
  puts "Message d'erreur : #{e.error}"
  puts "SQLSTATE d'erreur : #{e.sqlstate}" if e.respond_to?("sqlstate")
end

save = {}
sgroup = {}
first = {:COLOR => nil, :FACTION => nil, :SCORE => nil}
second = {:COLOR => nil, :FACTION => nil, :SCORE => nil}
tres = {:COLOR => nil, :FACTION => nil, :SCORE => nil}
cuatro = {:COLOR => nil, :FACTION => nil, :SCORE => nil}
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

bot = Discordrb::Commands::CommandBot.new token: DISCORD_BOT_TOKEN, client_id: DISCORD_BOT_CLIENT_ID, prefix: '42'

require "oauth2"
UID = OAUTH2_CLIENT_UID
SECRET = OAUTH2_CLIENT_SECRET
client = OAuth2::Client.new(UID, SECRET, site: "https://api.intra.42.fr")
token = client.client_credentials.get_token

def is_login? (event, token: false)
	res = $dbh.query("SELECT * FROM 42users WHERE discordid = #{event.user.id}")
	return true if res.fetch_row
	event.respond "Erreur, votre compte Discord n'est pas dans notre bdd des utilisateurs 42. Pour y remédier, allez sur ce lien : https://bit.ly/2Nej5eJ" if token == false
	false
end

def get_login (id)
	res = $dbh.query("SELECT * FROM 42users WHERE discordid = #{id}")
	return res.fetch_row[1]
end

def login (event)
	res = $dbh.query("SELECT * FROM 42users WHERE discordid = #{event.user.id}")
	return true if res.fetch_row
	false
end

bot.command(:reload, help_available: false) do |event|
  token = client.client_credentials.get_token
  event.respond "Le token 42 a bien ete recharge !"
  nil
end

bot.heartbeat do ||
   client = OAuth2::Client.new(UID, SECRET, site: "https://api.intra.42.fr")
   token = client.client_credentials.get_token
   bot.game = "42help"
   begin
  # connexion au serveur MySQL
    $dbh = Mysql.real_connect(SQL_HOST, LOGIN, PASSWORD, '42users')
  # r  cup  re la cha  ne de version du serveur et l'affiche
  #puts "Version du serveur: " + $dbh.get_server_info
  rescue Mysql::Error => e
    puts "Code d'erreur : #{e.errno}"
    puts "Message d'erreur : #{e.error}"
    puts "SQLSTATE d'erreur : #{e.sqlstate}" if e.respond_to?("sqlstate")
end
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
	infophone = token.get("/v2/users/" + login).parsed
	img = infophone["image_url"]
	phone = "Aucun" unless infophone["phone"]
	phone = infophone["phone"] unless phone == "Aucun"
	event.respond "Envoi des informations par message privé."
	event.user.pm.send_embed do |em|
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
	infoevent = token.get("/v2/campus/1/events").parsed
	#puts infoevent
	i = 0
	img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
	event.respond "Envoi des informations par message privé."
	event.user.pm.send_embed do |em|
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
	infoshop = token.get("v2/campus/1/products").parsed
	img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png' 
	event.respond "Envoi des informations par message privé."
	event.user.pm.send_embed do |em|
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
	bot.commands[:user].call(event, ['asandolo'])
	bot.commands[:user].call(event, ['ebertin'])
	nil
end

bot.command(:achievements, max_args: 1, min_args: 0, usage: "achievements [xlogin]", description: "voir les archievement") do |event, login|
  return if !is_login? event
  login = get_login event.user.id if login == nil
  img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
  infouser = token.get("/v2/users/" + login).parsed
  event.respond "Envoi des informations par message privé."
  event.user.pm.send_embed do |em|
    em.title = 'Archivements de ' + infouser["displayname"].to_s
    em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
    infouser["achievements"].each do |info|
      em.add_field(name: info["name"].to_s , value: info["description"].to_s)
    end
  end
  nil
end

bot.command(:savegroup, min_args: 1, usage: "savegroup xlogin ...", description: "Permet d'ajouter 1 ou plusieurs utilisateurs a votre groupe.") do |event, *args|
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
  if sgroup[event.user.id] == nil
    sgroup[event.user.id] = []
  end
  event.respond sgroup[event.user.id].to_s
end

bot.command(:deletegroup, min_args: 1, usage: "deletegroup xlogin ...", description: "Permet de supprimer 1 ou plusieurs utilisateurs de votre groupe.") do |event, *args|
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

bot.command(:group, usage: "group", description: "Permet d'afficher les utilisateurs de votre groupe. Cela vous permet avec une seule commande d'avoir des informations sur tout voutre groupe de travail, ce qui faut l'avouer est bien pratique.") do |event|
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
  if login == nil
    login = get_login event.user.id
  end
  img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
  infouser = token.get("/v2/users/" + login).parsed
  event.respond "Envoi des informations par message privé."
  event.user.pm.send_embed do |em|
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
  if login == nil
    login = get_login event.user.id
  end
  img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
  infouser = token.get("/v2/users/" + login).parsed
  event.respond "Envoi des informations par message privé."
  event.user.pm.send_embed do |em|
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

bot.command(:exam, max_args: 1, min_args: 0, usage: "exam [101]", description: "") do |event, campus|
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
  dt = infoexam[0]["begin_at"]
  dd = dt.split('T')
  puts dd[0].to_s
  date = dd[0].split('-')
  puts infoexam.to_s
  event.channel.send_embed do |embed|
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
	login = get_login event.user.id if login == nil
	begin
		infouser = token.get("/v2/users/#{login}").parsed
	rescue StandardError
		event.respond "Erreur, cet utilisateur n'existe pas."
		return
	end
	arr_msg = JSON.pretty_generate(infouser).to_s
	arr_msg = Discordrb.split_message(arr_msg)
	event.respond "Envoi des informations par message privé."
	arr_msg.each { |msg| event.user.pm "```JSON\n#{msg}\n```" }
	nil
end

bot.command(:quest, help_available: false) do |event, login|
	puts infoquest = token.get("/v2/users/#{login}/quests_users").parsed
	infoquest.each { |a| event.respond a["quest"].to_s if [3, 2, 1].include?(a["quest_id"]) && !a["validated_at"].nil? }
	nil
end

bot.command(:user, max_args: 1, min_args: 0, usage: "user <xlogin>", description: "") do |event, login|
  str =  " "
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
	begin
      event.channel.send_embed do |embed|
        embed.title = infouser["displayname"].to_s
        embed.image = Discordrb::Webhooks::EmbedImage.new(url: infouser["image_url"].to_s )
        if coauser[0] != nil
          if coauser[0]['slug'] == "the-assembly"
            embed.colour = "#a061d1"
          elsif coauser[0]['slug'] == "the-alliance"
            embed.colour = "#33c47f"
          elsif coauser[0]['slug'] == "the-order"
            embed.colour = "#ff6950"
	  elsif coauser[0]['slug'] == "the-blobfishes"
            embed.colour = "#82cce0"
	  elsif coauser[0]['slug'] == "the-skunks"
            embed.colour = "#6c8946"
	  elsif coauser[0]['slug'] == "the-sloths"
            embed.colour = "#ffa9c6"
	  elsif coauser[0]['slug'] == "the-worms"
            embed.colour = "#eab77f"
          else
            embed.colour = "#4180db"
          end
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
    rescue Exception
      puts "Une Erreur c'est produite dans l'envois d'un des messages."
    end
  else
    event.respond "Merci de preciser un login !"
  end
  nil
end

bot.command(:save, usage: "save <xlogin>", description: "Permet de d'identifier votre compte 42.") do |event, log|
  event.respond "Pour vous enregister, vous pouvez vous rendre sur ce lien : https://bit.ly/2Nej5eJ"
end

# Le code du dessous date d'une nuit blanche a la suite de 24H de boulot, je faisais du Ruby 3 mois et
# Alex c'était sa premiere fois. Me jugez pas.

bot.command(:coapool, max_args: 0, min_args: 0, usage: "coa", description: "") do |event|
  infocoa = token.get("/v2/blocs/3/coalitions").parsed
	
  sor = infocoa[0]["score"]
  sas = infocoa[1]["score"]
  sal = infocoa[2]["score"]
  sfe = infocoa[3]["score"]

  if sor > sas && sor > sal && sor > sfe
    first[:SCORE] = sor
    first[:FACTION] = "The Blobfishes"
    first[:COLOR] = "#82cce0"
    image = "https://cdn.discordapp.com/attachments/315430063728361472/464158581126594570/unknown.png"
    sor = 0
  elsif sas > sor && sas > sal && sas > sfe
    first[:SCORE] = sas
    first[:FACTION] = "The Skunks"
    first[:COLOR] = "#6c8946"
    image = "https://cdn.discordapp.com/attachments/315430063728361472/464158523199062027/unknown.png"
    sas = 0
  elsif sal > sor && sal > sas && sal > sfe
    first[:SCORE] = sal
    first[:FACTION] = "The Sloths"
    first[:COLOR] = "#ffa9c6"
    image = "https://cdn.discordapp.com/attachments/315430063728361472/464158628505714698/unknown.png"
    sal = 0
  else
    first[:SCORE] = sfe
    first[:FACTION] = "The Worms"
    first[:COLOR] = "#eab77f"
    image = "https://cdn.discordapp.com/attachments/315430063728361472/464158408174469120/unknown.png"
    sfe = 0
  end
  if sor > sas && sor > sal && sor > sfe
    second[:SCORE] = sor
    second[:FACTION] = "The Blobfishes"
    sor = 0
  elsif sas > sor && sas > sal && sas > sfe
    second[:SCORE] = sas
    second[:FACTION] = "The Skunks"
    sas = 0
  elsif sal > sor && sal > sas && sal > sfe
    second[:SCORE] = sal
    second[:FACTION] = "The Sloths"
    sal = 0
  else
    second[:SCORE] = sfe
    second[:FACTION] = "The Worms"
    sfe = 0
  end
  if sor > sas && sor > sal && sor > sfe
    tres[:SCORE] = sor
    tres[:FACTION] = "The Blobfishes"
    sor = 0
  elsif sas > sor && sas > sal && sas > sfe
    tres[:SCORE] = sas
    tres[:FACTION] = "The Skunks"
    sas = 0
  elsif sal > sor && sal > sas && sal > sfe
    tres[:SCORE] = sal
    tres[:FACTION] = "The Sloths"
    sal = 0
  else
    tres[:SCORE] = sfe
    tres[:FACTION] = "The Worms"
    sfe = 0
  end
  if sor > sas && sor > sal && sor > sfe
    cuatro[:SCORE] = sor
    cuatro[:FACTION] = "The Blobfishes"
  elsif sas > sor && sas > sal && sas > sfe
    cuatro[:SCORE] = sas
    cuatro[:FACTION] = "The Skunks"
  elsif sal > sor && sal > sas && sal > sfe
    cuatro[:SCORE] = sal
    cuatro[:FACTION] = "The Sloths"
  else
    cuatro[:SCORE] = sfe
    cuatro[:FACTION] = "The Worms"
  end
  #begin

  sone = first[:SCORE]-second[:SCORE]
  sto = second[:SCORE]-tres[:SCORE]
  stre = tres[:SCORE]-cuatro[:SCORE]
  event.channel.send_embed do |em|
    em.title = "Classement des Coalitions"
    em.colour = first[:COLOR]
	em.url = "https://profile.intra.42.fr/blocs/3/coalitions"
    em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: image)
    em.add_field(name: 'Premier :', value: first[:FACTION] + ' score ' + first[:SCORE].to_s)
    em.add_field(name: 'Deuxieme :', value: second[:FACTION] + ' score ' + second[:SCORE].to_s + ' (-' + sone.to_s +  ')')
    em.add_field(name: 'Troisieme :', value: tres[:FACTION] + ' score ' + tres[:SCORE].to_s + ' (-' + sto.to_s  +  ')')
    em.add_field(name: 'Dernier :', value: cuatro[:FACTION] + ' score ' + cuatro[:SCORE].to_s + ' (-' + stre.to_s  +  ')')
  end
  #rescue Exception
  #puts "Une Erreur c'est produite dans l'envois d'un des messages."
  #end
  nil
end

# Pareil pour lui

bot.command(:coa, max_args: 0, min_args: 0, usage: "coa", description: "") do |event|
  infocoa = token.get("/v2/blocs/1/coalitions").parsed

	puts infocoa
	
  sor = infocoa[0]["score"]
  sas = infocoa[1]["score"]
  sal = infocoa[2]["score"]
  sfe = infocoa[3]["score"]

  if sor > sas && sor > sal && sor > sfe
    first[:SCORE] = sor
    first[:FACTION] = "The Order"
    first[:COLOR] = "#ff6950"
    image = "https://cdn.discordapp.com/attachments/378481743679979523/388333775366389761/unknown.png"
    sor = 0
  elsif sas > sor && sas > sal && sas > sfe
    first[:SCORE] = sas
    first[:FACTION] = "The Assembly"
    first[:COLOR] = "#a061d1"
    image = "https://cdn.discordapp.com/attachments/378481743679979523/388333506301919234/unknown.png"
    sas = 0
  elsif sal > sor && sal > sas && sal > sfe
    first[:SCORE] = sal
    first[:FACTION] = "The Alliance"
    first[:COLOR] = "#33c47f"
    image = "https://cdn.discordapp.com/attachments/378481743679979523/388333355780800513/unknown.png"
    sal = 0
  else
    first[:SCORE] = sfe
    first[:FACTION] = "The Federation"
    first[:COLOR] = "#4180db"
    image = "https://cdn.discordapp.com/attachments/378481743679979523/388333662233559061/unknown.png"
    sfe = 0
  end
  if sor > sas && sor > sal && sor > sfe
    second[:SCORE] = sor
    second[:FACTION] = "The Order"
    sor = 0
  elsif sas > sor && sas > sal && sas > sfe
    second[:SCORE] = sas
    second[:FACTION] = "The Assembly"
    sas = 0
  elsif sal > sor && sal > sas && sal > sfe
    second[:SCORE] = sal
    second[:FACTION] = "The Alliance"
    sal = 0
  else
    second[:SCORE] = sfe
    second[:FACTION] = "The Federation"
    sfe = 0
  end
  if sor > sas && sor > sal && sor > sfe
    tres[:SCORE] = sor
    tres[:FACTION] = "The Order"
    sor = 0
  elsif sas > sor && sas > sal && sas > sfe
    tres[:SCORE] = sas
    tres[:FACTION] = "The Assembly"
    sas = 0
  elsif sal > sor && sal > sas && sal > sfe
    tres[:SCORE] = sal
    tres[:FACTION] = "The Alliance"
    sal = 0
  else
    tres[:SCORE] = sfe
    tres[:FACTION] = "The Federation"
    sfe = 0
  end
  if sor > sas && sor > sal && sor > sfe
    cuatro[:SCORE] = sor
    cuatro[:FACTION] = "The Order"
  elsif sas > sor && sas > sal && sas > sfe
    cuatro[:SCORE] = sas
    cuatro[:FACTION] = "The Assembly"
  elsif sal > sor && sal > sas && sal > sfe
    cuatro[:SCORE] = sal
    cuatro[:FACTION] = "The Alliance"
  else
    cuatro[:SCORE] = sfe
    cuatro[:FACTION] = "The Federation"
  end
  #begin

  sone = first[:SCORE]-second[:SCORE]
  sto = second[:SCORE]-tres[:SCORE]
  stre = tres[:SCORE]-cuatro[:SCORE]
  event.channel.send_embed do |em|
    em.title = "Classement des Coalitions"
    em.colour = first[:COLOR]
	em.url = "https://profile.intra.42.fr/blocs/1/coalitions"
    em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: image)
    em.add_field(name: 'Premier :', value: first[:FACTION] + ' score ' + first[:SCORE].to_s)
    em.add_field(name: 'Deuxieme :', value: second[:FACTION] + ' score ' + second[:SCORE].to_s + ' (-' + sone.to_s +  ')')
    em.add_field(name: 'Troisieme :', value: tres[:FACTION] + ' score ' + tres[:SCORE].to_s + ' (-' + sto.to_s  +  ')')
    em.add_field(name: 'Dernier :', value: cuatro[:FACTION] + ' score ' + cuatro[:SCORE].to_s + ' (-' + stre.to_s  +  ')')
  end
  #rescue Exception
  #puts "Une Erreur c'est produite dans l'envois d'un des messages."
  #end
  nil
end

# La techno de détection des commandes sur messages édités. 

bot.message_edit do |event|
	args = event.message.content.split(' ')
	args.delete_at(0)
	bot.commands.each_key do |key|
		bot.commands[key].call(event, args) if event.message.content.scan(/^42#{Regexp.quote(key)}/).count > 0
	end
	nil
end

bot.run
