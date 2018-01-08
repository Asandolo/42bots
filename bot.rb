require 'discordrb'
require 'oauth2'

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

bot = Discordrb::Commands::CommandBot.new token: 'DISCORD_TOKEN', client_id: 'DISCORD_CLIENT_ID', prefix: 'PREFIX'

UID = "42_UUID"
SECRET = "42_SECRET"
client = OAuth2::Client.new(UID, SECRET, site: "https://api.intra.42.fr")
token = client.client_credentials.get_token

bot.command(:reload, help_available: false) do |event|
  token = client.client_credentials.get_token
  event.respond "Le token 42 a bien ete rechargé !"
  nil
end

bot.heartbeat do ||
    client = OAuth2::Client.new(UID, SECRET, site: "https://api.intra.42.fr")
    token = client.client_credentials.get_token
    bot.game = "42help"
    nil
end

bot.command(:invit, max_args: 0, min_args: 0, usage: "invit", description: "Lien d'invitation du bot") do |event|
  event.respond "https://discordapp.com/oauth2/authorize?&client_id=388110639220129813&scope=bot&permissions=0"
end

bot.command(:source, max_args: 0, min_args: 0, usage: "source", description: "Lien du code source") do |event|
  event.respond "https://github.com/Asandolo/42bots"
end

bot.command(:achievements, max_args: 1, min_args: 0, usage: "achievements [xlogin]", description: "") do |event, login|
  if login == nil
    if save[event.user.id] != nil
      login = save[event.user.id]
    end
  end
  img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
  infouser = token.get("/v2/users/" + login).parsed
  event.channel.send_embed do |em|
    em.title = 'Archivements de ' + infouser["displayname"].to_s
    em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
    infouser["achievements"].each do |info|
      em.add_field(name: info["name"].to_s , value: info["description"].to_s)
    end
  end
end

bot.command(:savegroup, min_args: 1, usage: "savegroup xlogin ...", description: "Permet d'ajouter 1 ou plusieurs utilisateurs a votre groupe.") do |event, *args|
  if sgroup[event.user.id] == nil
    sgroup[event.user.id] = []
  end
    args.each do |use|
      if token.get("/v2/users/" + use).parsed != nil
        sgroup[event.user.id] << [use]
        File.open("group.42", "w") do |f|
          Marshal.dump(sgroup, f)
        end
      else
        event.respond use + " n'est pas enregistré dans la base de donnés de 42 !"
      end
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
  if sgroup[event.user.id] != []
    event.channel.send_embed do |embed|
        embed.title = event.user.name
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
end

bot.command(:project, max_args: 1, min_args: 0, usage: "project [xlogin]", description: "") do |event, login|
  if login == nil
    if save[event.user.id] != nil
      login = save[event.user.id]
    end
  end
  img = 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png'
  infouser = token.get("/v2/users/" + login).parsed

  event.channel.send_embed do |em|
    em.title = 'Projets de ' + infouser["displayname"].to_s
    em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: img)
    i = 0
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
end


bot.command(:user, max_args: 1, min_args: 0, usage: "user <xlogin>", description: "") do |event, login|
  if login == nil
    if save[event.user.id] != nil
      login = save[event.user.id]
    end
  end
  if login != nil
    infouser = token.get("/v2/users/" + login).parsed
    coauser = token.get("/v2/users/" +  login + "/coalitions").parsed
    #begin
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
          else
            embed.colour = "#4180db"
          end
        else
          embed.colour = "#5c5c5c"
        end
        embed.description = 'Informations de ' + infouser["displayname"].to_s
        embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: 'Ecole 42')
        embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: 'https://www.defi-metiers.fr/sites/default/files/doc-kelios/Logo/2015/07/23/42_Final_sigle_seul_copie.png')
        embed.url = "http://intra.42.fr/users/" + infouser["login"].to_s
        if infouser["location"] != nil
          embed.add_field(name: 'Location', value: infouser["location"].to_s)
        else
          embed.add_field(name: 'Location', value: 'Unavailable')
        end
        embed.add_field(name: 'Wallet', value: infouser["wallet"].to_s)
        embed.add_field(name: 'lvl / grade :', value: infouser["cursus_users"][0]["level"].to_s + " / " + infouser["cursus_users"][0]["grade"].to_s)
      end
    #rescue Exception
      puts "Une Erreur c'est produite dans l'envois d'un des messages."
    #end
  else
    event.respond "Merci de preciser un login !"
  end
  nil
end

bot.command(:save, max_args: 1, min_args: 1, usage: "save <xlogin>", description: "Permet de sauvegarder son compte pour pas le retaper a chaque fois.") do |event, log|
  save[event.user.id] = log
  File.open("save.42", "w") do |f|
    Marshal.dump(save, f)
  end
  nil
end

bot.command(:coa, max_args: 0, min_args: 0, usage: "coa", description: "") do |event|
  infocoa = token.get("/v2/coalitions").parsed

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
  event.channel.send_embed do |em|
    em.title = "Classement des Coalitions"
    em.colour = first[:COLOR]
    em.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: image)
    em.add_field(name: 'Premier :', value: first[:FACTION] + ' score ' + first[:SCORE].to_s)
    em.add_field(name: 'Deuxieme :', value: second[:FACTION] + ' score ' + second[:SCORE].to_s)
    em.add_field(name: 'Troisieme :', value: tres[:FACTION] + ' score ' + tres[:SCORE].to_s)
    em.add_field(name: 'Dernier :', value: cuatro[:FACTION] + ' score ' + cuatro[:SCORE].to_s)
  end
  #rescue Exception
  #puts "Une Erreur c'est produite dans l'envois d'un des messages."
  #end
end

bot.run
