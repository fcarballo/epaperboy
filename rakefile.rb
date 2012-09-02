require 'yaml'
require 'nokogiri'
require 'uri'
require 'cgi'
require 'mechanize'
require 'pdf/reader'

def directory_tree
   files = Array.new
   Dir.new(Dir.pwd).entries.each { |n| files.push(n) if File.file?(n) && n.include?("pdf") }
   files
end

MEGABYTE = 1024 * 1024

today = Date.today.strftime("%d%m%Y")
lpg_url = "http://kiosko.laprensagrafica.com/xml_epaper/La%20Prensa%20Grafica/#{Date.today.strftime("%d_%m_%Y")}/pla_2_La_Prensa_Gr%C3%A1fica.xml"
edh_url = "http://epaper.elsalvador.com/edicion/html/#{Date.today.strftime("%Y%m%d")}/pagedata35.xml"
lpg_pdf_url = "http://kiosko.laprensagrafica.com/xml_epaper/La%20Prensa%20Grafica/"
edh_pdf_url = "http://epaper.elsalvador.com/edicion/html/"

namespace :run do
  desc 'Iniciar app en modo desarrollo'  
  task :dev do
    #sh 'bundle exec shotgun --server=thin config.ru'
    sh 'bundle exec rerun --pattern "**/*.{rb,erb,html,ru}" -- bundle exec thin start --debug -R config.ru'
  end

  desc 'Iniciar app en modo produccion'
  task :prod do
    sh 'bundle exec thin -d start -R config.ru -e production'
  end
end

namespace :download do

  desc 'Descargando La Prensa Grafica'
  task :all => [:lpg,:edh] do
    pdf_lpg = PDF::Reader.new("public/epapers/lpg#{today}.pdf")
    file_lpg = File.open("public/epapers/lpg#{today}.pdf", "r")
    file_metadata_lpg = File.new("public/epapers/lpg_metadata.txt", "w+")
    pdf_edh = PDF::Reader.new("public/epapers/edh#{today}.pdf")
    file_edh = File.open("public/epapers/edh#{today}.pdf", "r")
    file_metadata_edh = File.new("public/epapers/edh_metadata.txt", "w+")

    file_metadata_lpg.puts(pdf_lpg.page_count)
    file_metadata_lpg.puts(file_lpg.mtime.strftime("%d/%m/%Y %H:%M:%S"))
    file_metadata_lpg.puts((file_lpg.size.to_f / MEGABYTE).round(2))
    file_metadata_edh.puts(pdf_edh.page_count)
    file_metadata_edh.puts(file_edh.mtime.strftime("%d/%m/%Y %H:%M:%S"))
    file_metadata_edh.puts((file_edh.size.to_f / MEGABYTE).round(2))

    system("mv public/epapers/lpg#{today}.pdf public/epapers/lpg.pdf")
    system("mv public/epapers/edh#{today}.pdf public/epapers/edh.pdf")

  end

  desc 'Descargando La Prensa Grafica'
  task :lpg do
	agent = Mechanize.new
	page = agent.get(lpg_url)
	doc = Nokogiri::XML.parse(page.body)

	doc.xpath('//PAGINAS//PAGINA').each_with_index{|n,i| 
	   a =  n.attributes
	   if !a["FILE_PDF"].nil?
		one_pdf_url = "#{lpg_pdf_url}"+a["FILE_PDF"]
		puts one_pdf_url
		#system("wget " + one_pdf_url + " -q")
		agent.get(one_pdf_url).save("lpg#{i.to_s.rjust(4, '0')}.pdf")
	   end
	}

	directory_tree.each do |file|
		 begin
		  pdf = PDF::Reader.new(file.to_s)
		  if pdf.page_count == 0
		     File.delete(file)	
		  end
		 rescue			
		  #Si el pdf no puede ser abierto por alguna razon esta corrupto y sera eliminado
		  File.delete(file)
		 end	
	end

	system("pdftk *.pdf cat output lpg#{today}.xxx")
	system("rm *.pdf")
	system("mv lpg#{today}.xxx public/epapers/lpg#{today}.pdf")

  end

  desc 'Descargando El Diario de Hoy'
  task :edh do
	#Login
	agent = Mechanize.new
	page = agent.get("https://epaper.elsalvador.com/login.aspx")
	form = page.form_with(:id => 'frmLogin')
	form.field_with(:name => "txtUsuario").value = 'AQUI VA EL USERNAME'
	form.field_with(:name => "txtPassword").value = 'AQUI VA EL PASSWORD'
	form.add_field!('__EVENTTARGET','lnkBtnLogin')
	page = form.click_button

	page = agent.get(edh_url)
	doc = Nokogiri::XML.parse(page.body)

	doc.xpath('//PageData').each_with_index{|n,i| 
	    a =  n.attributes
	    one_pdf_url = "#{edh_pdf_url}"+a["LargeFile"].value.gsub("SWF","pdf")
	    puts one_pdf_url
	    agent.get(one_pdf_url).save("edh#{i.to_s.rjust(4, '0')}.pdf")
	}
	puts "Esperando..."
	sleep 15 #necesario para darle tiempo a mechanize que termine de descargar el ultimo pdf

	#validar que todos los pdfs no esten corruptos
	directory_tree.each do |file|
		 begin
		  pdf = PDF::Reader.new(file.to_s)
		  if pdf.page_count == 0
		     File.delete(file)	
		  end
		 rescue			
		  #Si el pdf no puede ser abierto por alguna razon esta corrupto y sera eliminado
		  File.delete(file)
		 end	
	end

	system("pdftk *.pdf cat output edh#{today}.xxx")
	system("rm *.pdf")
	system("mv edh#{today}.xxx public/epapers/edh#{today}.pdf")

  end
end
