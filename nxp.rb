# encoding: utf-8  
#!/usr/bin/env ruby  
  
require 'nexpose'  
require 'asciiart' 
require 'highline/import'
  
host = 'localhost'  
uname = 'nxadmin'  
passwd = 'nxpassword'
dirname = Dir.pwd
dirname = dirname + '/data'

asciia = AsciiArt.new("image/rhino.jpg")
puts asciia.to_ascii_art(width: 50, color: true) 

begin
  linfoname = dirname + '/login.info'
  loginArray = IO.readlines(linfoname) 
rescue Exception
  exit unless HighLine.agree('Cannot read login file, manually enter credentials? Y/N')
  puts 'Enter Host'
  host = gets.chomp 
  puts 'Enter Username'
  uname = gets.chomp 
  puts 'Enter Password'
  passwd = gets.chomp
else
  puts '[+] Parsed login information from file'
  host = loginArray[0]
  host.chomp!
  host.strip!
  uname = loginArray[1]
  uname.chomp!
  uname.strip!
  passwd = loginArray[2]
  passwd.chomp!
  passwd.strip!
end

nsc = Nexpose::Connection.new(host, uname, passwd)
puts '[+] Logging into Nexpose' 
puts
 
begin  
  nsc.login 
rescue Exception
  puts 'Invalid Credentials'
  exit
else
  puts '[+] Logged into Nexpose'
  puts   
end

print "\tEnter Name of Site: "
@name = gets.chomp
print "\n\tEnter the name of the file containing the list of targets: "
@file = gets.chomp
tinfoname = dirname + '/' + @file
ipArray=[]

begin  
  ipArray = IO.readlines(tinfoname)
  ipArray.map!{|x| x.chomp }
rescue Exception
  puts '[!] File does not exist'
  exit
else
  puts   
end

puts "Scan Information\nName: #{@name} \nIPs Parsed: #{ipArray}"

exit unless HighLine.agree('Does this look right? Y/N')
  
puts "[+] Creating site #{@name} [+] Scanning the hosts in the file #{@file}" 

site = Nexpose::Site.new(@name) 
 
for ip in ipArray
  site.add_ip(ip)  
end

if ipArray.length > 256
  puts 'Please enter less than 256 IPs'
end

site.save(nsc) 
 
puts '[+] Created site successfully!'  
puts '[+] Starting scan' 
 
scan = site.scan(nsc)  
scanid = scan.id
status = nsc.scan_status(scan.id) 
puts "\t\t[!] Current scan status: #{status.to_s}"
  
begin  
  sleep(15)  
  status = nsc.scan_status(scan.id)  
end while status == Nexpose::Scan::Status::RUNNING  
  
puts '[+] Scan complete' 
sleep(30) 


puts '[!] Generating reports. . .'


namex = @name + ' XML Report'
report = Nexpose::ReportConfig.new(namex, 'audit-report', 'xml')
report.add_filter('site', site.id)
id = report.save(nsc, true)
puts '[+] XML report generated'
last = nsc.last_report(id)
data = nsc.download(last.uri)

namep = @name + ' PDF Report'
report = Nexpose::ReportConfig.new(namep, 'audit-report', 'pdf')
report.add_filter('site', site.id)
id = report.save(nsc, true)
puts '[+] PDF report generated'
last = nsc.last_report(id)
data = nsc.download(last.uri)

puts "[+] Reports saved"



    
puts '[+] Report completed and saved. deleting Site'  
site.delete(nsc)  
  
puts '[+] Logging out'  
nsc.logout  
exit  
